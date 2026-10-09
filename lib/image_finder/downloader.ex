defmodule ImageFinder.Downloader do
  # módulo descargador. Extraído del fetch_link/2 del worker original,
  # que hacia `{:ok, response} = Tesla.get(link)`: cualquier fallo (link caído,
  # 404, timeout) era un MatchError que mataba todo el proceso de descarga.

  @max_retries 3

  def download(link, dir, attempts \\ @max_retries)

  # NEW: corte de retry: agotados los 3 intentos, se devuelve {:error, :retries_exceeded}.
  # Nunca se lanza una excepción: el fallo se reporta y el llamador decide.
  # (Requerimiento README parte 2: "si la descarga falla, reintentar hasta 3 veces".)
  def download(_link, _dir, 0 = _attempts), do: {:error, :retries_exceeded}

  def download(link, dir, attempts) do
  # case en lugar de match estricto. Solo 2xx se considera éxito;
  # cualquier otro status o error de red va a retry/1. Así "el error en una
  # descarga no hace fallar todo el proceso" (README parte 1).
    case Tesla.get(link) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        File.write!(Path.join(dir, digest(body)), body)

      {:ok, %{status: status}} ->
        retry(link, dir, attempts, "HTTP #{status}")

      {:error, reason} ->
        retry(link, dir, attempts, inspect(reason))
    end
  end

  # NEW: reintento con espera simple entre intentos y log del motivo. 
  defp retry(link, dir, attempts, reason) do
    require Logger
    Logger.warning("download failed (#{link}): #{reason} — retrying (#{attempts - 1} left)")
    Process.sleep(500)
    download(link, dir, attempts - 1)
  end

  # Igual que el digest/1 original: nombre de archivo = hash MD5 del contenido.
  defp digest(body), do: :crypto.hash(:md5, body) |> Base.encode16()
end