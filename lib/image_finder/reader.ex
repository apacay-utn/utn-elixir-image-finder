# NEW: módulo lector. Reemplaza el File.read! + Regex.scan sobre TODO el
# contenido del worker original, que (a) exigía el archivo completo en memoria
# y (b) no descargaba nada hasta terminar de leer.

defmodule ImageFinder.Reader do
  @regex ~r/http(s?)\:.*?\.(png|jpg|gif)/


# NEW: lectura incremental. File.stream!/1 lee el archivo línea por línea
# (lazy): cada línea se escanea apenas llega, sin cargar el archivo entero.
# Stream.flat_map encadena el regex sobre ese flujo, y Enum.each consume.
# Cumple dos requerimientos del README: archivos más grandes que la memoria
# y "ir descargando links a medida que se leen del archivo".
  def run(file, dir) do
    file
    |> File.stream!()
    |> Stream.flat_map(&Regex.scan(@regex, &1))
    |> Enum.each(fn [link | _] ->
    
    # NEW: cada link se despacha a un proceso propio de descarga. Las
    # descargas corren en paralelo entre sí (throughput) y aisladas: si un
    # link crashea, ese proceso muere solo y no arrastra al lector.
    # (En Parte 2 este despacho migra al DomainWorker para politeness.)
      Task.Supervisor.start_child(ImageFinder.TaskSup, fn ->
        ImageFinder.Downloader.download(link, dir)
    # ImageFinder.DomainWorker.download(link, dir)
    
      end)
    end)
  end
end