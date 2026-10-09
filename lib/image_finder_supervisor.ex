defmodule ImageFinder.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # NEW: jerarquía de supervisión. El worker único registrado (Worker1) era el
  # cuello de botella: serializaba todos los fetch del sistema y su crash
  # (restart: :transient, max_restarts: 5) dejaba la app sin servicio.
  # Lo reemplaza un Task.Supervisor: padre de los lectores (uno por fetch)
  # y de las descargas (una por link), cada uno aislado.
  # En Parte 2 se suman Registry + DynamicSupervisor para los DomainWorkers.
  def init(_init_arg) do
    children = [
      # %{id: ImageFinder.Worker, start: {ImageFinder.Worker, :start_link, [Worker1]}, restart: :transient},

      # PARTE 2 {Registry, keys: :unique, name: ImageFinder.Registry},
      {Task.Supervisor, name: ImageFinder.TaskSup}
      # PARTE 2 {DynamicSupervisor, name: ImageFinder.DomainSup, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end