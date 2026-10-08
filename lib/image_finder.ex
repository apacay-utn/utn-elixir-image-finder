defmodule ImageFinder do
  use Application

  def start(_type, _args) do
    name_application()
    ImageFinder.Supervisor.start_link(:ok)
  end

  def name_application() do
    Process.register(self(), ImageFinder)
  end

  def fetch(source_file, target_directory) do
    GenServer.call(Worker1, {:fetch, source_file, target_directory})
  end
end

# ImageFinder.fetch("sample2.txt", "./out")
