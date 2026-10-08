defmodule ImageFinder.Worker do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:fetch, source_file, target_directory}, _from, state) do
    content = File.read!(source_file)
    regexp = ~r/http(s?)\:.*?\.(png|jpg|gif)/
    scanResult = Regex.scan(regexp, content)
    links = Enum.map(scanResult, fn [match | _] -> match end)
    IO.puts("Found #{length(links)} links in #{source_file}")
    Enum.map(links, fn link -> fetch_link(link, target_directory) end)
    {:reply, :ok, state}
  end

  def fetch_link(link, target_directory) do
    {:ok, response} = Tesla.get(link)
    response.body |> save(target_directory)
  end

  def digest(body) do
    :crypto.hash(:md5, body) |> Base.encode16()
  end

  def save(body, directory) do
    IO.puts("Saving file #{digest(body)} in #{directory}")
    File.write!("#{directory}/#{digest(body)}", body)
  end
end
