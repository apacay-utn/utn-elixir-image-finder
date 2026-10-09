# NEW: fetch ya no es un GenServer.call a un worker único (eso bloqueaba al
# llamador hasta terminar TODAS las descargas y solo permitía un archivo a la vez).
# Ahora: valida que el archivo exista (manejo de errores del README: si la lectura
# falla, no se extrae ningún link -> devolvemos {:error, :enoent} sin crash),
# y spawnea un proceso LECTOR por invocación bajo el Task.Supervisor.
# Por eso devuelve :ok inmediatamente: el trabajo pesado pasa a otro proceso.

defmodule ImageFinder do
  use Application

  def start(_type, _args) do
    ImageFinder.Supervisor.start_link(:ok)
  end

  def fetch(source_file, target_directory) do
    if File.regular?(source_file) do
      Task.Supervisor.start_child(ImageFinder.TaskSup, fn ->
        ImageFinder.Reader.run(source_file, target_directory)
      end)
      :ok
    else
      {:error, :enoent}
    end
  end
end

# ImageFinder.fetch("sample2.txt", "./out")

