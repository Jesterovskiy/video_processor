defmodule VideoProcessor.Periodically do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(state) do
    Process.send(self(), :work, [])
    {:ok, state}
  end

  def handle_info(:work, state) do
    response = Confex.get(:video_processor, :complex_feed_url) |> fetch_complex()
    process_complex_items(Floki.find(response.body, "item"), parse_xml(response.body, "next_page"), 1)
    if Confex.get(:video_processor, :schedule_work) == "true", do: schedule_work()
    {:noreply, state}
  end

  defp process_complex_items(complex_items, next_page, counter) do
    Enum.each(complex_items, fn(item) -> check_state_and_run(item) end)
    counter = counter - 1
    if counter != 0 do
      response = next_page |> fetch_complex()
      next_page = parse_xml(response.body, "next_page")
      process_complex_items(Floki.find(response.body, "item"), next_page, counter)
    else
      IO.puts "Process Complex Items Finished"
    end
  end

  defp fetch_complex(url) do
    url |> HTTPoison.get!([], [timeout: 50000])
  end

  defp schedule_work do
    IO.puts "Schedule Work"
    Process.send_after(self(), :work, 5 * 60 * 1000)
  end

  defp parse_xml(item, element) do
    result = Floki.find(item, element)
    if result |> List.first, do: result |> List.first |> elem(2) |> List.first, else: ""
  end

  def check_state_and_run(complex_media) do
    filename = parse_xml(complex_media, "guid") <> ".mp4"
    download_dir = Confex.get(:video_processor, :download_dir)
    :dets.open_file(Confex.get(:video_processor, :disk_storage), [type: :set])
    case :dets.lookup(Confex.get(:video_processor, :disk_storage), filename) do
      [] ->
        GenServer.call(VideoProcessor.Download, {:process, complex_media})
      # [{filename, "download_finish"}] ->
      #   GenServer.call(VideoProcessor.S3Upload, {:process, complex_media})
      # [{filename, "s3_upload_finish"}] ->
      #   GenServer.call(VideoProcessor.UplynkUpload, {:process, complex_media})
      [{filename, "done"}] ->
        File.rm(download_dir <> "/" <> filename)
        IO.puts filename <> " complete"
    end
    :dets.close(Confex.get(:video_processor, :disk_storage))
  end
end
