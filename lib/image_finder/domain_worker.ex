defmodule ImageFinder.DomainWorker do
  # NEW (parte 2): actor de politeness. Un proceso por DOMINIO, registrado en el
  # Registry por nombre de dominio. Como un GenServer procesa sus casts de a uno
  # por vez, todos los links del mismo dominio se descargan en serie (= polite:
  # no sobrecargamos a un mismo servidor), mientras que dominios distintos
  # corren en paralelo (workers separados).

  use GenServer
  require Logger

  @failure_limit 5
  @window_ms 60_000

  # NEW: API de entrada. Garantiza que exista el worker del dominio del link
  # (creándolo bajo el DynamicSupervisor la primera vez que aparece) y le
  # encola el link. Si dos links del mismo dominio llegan juntos, ambos caen
  # en el mismo worker y se serializan.
  # Un worker por dominio; si ya existe, reusa el existente
  def download(link, dir) do
    domain = URI.parse(link).host

    case GenServer.whereis({:via, Registry, {ImageFinder.Registry, domain}}) do
      nil ->
      # NEW: primera vez que vemos este dominio: lo arrancamos. El
      # already_started cubre la carrera de dos links simultáneos del mismo
      # dominio nuevo (ambos ven nil, uno gana, el otro recibe
      # {:error, {:already_started, pid}} y simplemente sigue).

        case DynamicSupervisor.start_child(
               ImageFinder.DomainSup,
               {__MODULE__, domain}
             ) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

        GenServer.cast(
          {:via, Registry, {ImageFinder.Registry, domain}},
          {:download, link, dir}
        )

      pid ->
        GenServer.cast(pid, {:download, link, dir})
    end
  end

  def start_link(domain) do
    GenServer.start_link(__MODULE__, domain,
      name: {:via, Registry, {ImageFinder.Registry, domain}}
    )
  end


  @impl true
  # NEW: el estado guarda el dominio y la lista de timestamps de fallos
  # recientes (o el átomo :blocked una vez excluido).
  def init(domain), do: {:ok, %{domain: domain, failures: []}}

  @impl true
  # NEW: dominio ya bloqueado: los links se descartan con log. El worker
  # queda vivo a propósito: si terminara, el Registry liberaría el nombre y un
  # link posterior recrearía el worker como si nada, eludiendo la exclusión.
  def handle_cast({:download, _link, _dir}, state = %{failures: :blocked}) do
    Logger.warning("domain #{state.domain} is blocked, dropping link")
    {:noreply, state}
  end

  # NEW: descarga serializada del link (el Downloader ya trae su retry x3).
  # Si el link agotó sus reintentos, registra el fallo para el dominio.
  def handle_cast({:download, link, dir}, state) do
    case ImageFinder.Downloader.download(link, dir) do
      {:error, :retries_exceeded} ->
        # NEW: ventana móvil de fallos: nos quedamos solo con los fallos de los
        # últimos @window_ms ms. Si superan el límite, el dominio pasa a
        # :blocked (autoexclusión del README: >5 fallos/minuto).
        now = System.monotonic_time(:millisecond)

        failures =
          [now | state.failures]
          |> Enum.filter(&is_integer(&1))
          |> Enum.take_while(&(now - &1 < @window_ms))

        if length(failures) > @failure_limit do
          Logger.warning("domain #{state.domain} exceeded #{@failure_limit} failures/min, blocking")
          {:noreply, %{state | failures: :blocked}}
        else
          {:noreply, %{state | failures: failures}}
        end

      _success_or_http_error ->
        {:noreply, state}
    end
  end
end