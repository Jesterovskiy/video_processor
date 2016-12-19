defmodule VideoProcessor.Periodically do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    if Confex.get(:video_processor, :schedule_work) == "true", do: Process.send(self(), :work, [])
    {:ok, state}
  end

  def handle_info(:work, state) do
    response = Confex.get(:video_processor, :complex_feed_url) |> HTTPoison.get!
    Enum.each(Floki.find(response.body, "item"),
      fn(x) ->
        filename = parse_xml(x, "guid") <> ".mp4"
        check_state_and_run(filename, parse_xml(x, "link"))
      end
    )
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work do
    IO.puts "Schedule Work"
    Process.send_after(self(), :work, 5 * 60 * 1000)
  end

  defp parse_xml(item, element) do
    Floki.find(item, element) |> List.first |> elem(2) |> List.first
  end

  def check_state_and_run(filename, url) do
    :dets.open_file(Confex.get(:video_processor, :disk_storage), [type: :set])
    case :dets.lookup(Confex.get(:video_processor, :disk_storage), filename) do
      [] ->
        GenServer.call(VideoProcessor.Download, {:process, [url, filename]})
      [{filename, "download_finish"}] ->
        GenServer.call(VideoProcessor.S3Upload, {:process, filename})
      [{filename, "s3_upload_finish"}] ->
        GenServer.call(VideoProcessor.UplynkUpload, {:process, filename})
      [{filename, "done"}] ->
        IO.puts filename <> " complete"
    end
    :dets.close(Confex.get(:video_processor, :disk_storage))
  end
end
