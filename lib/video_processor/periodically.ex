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
    process_complex_items(Floki.find(response.body, "item"), parse_xml(response.body, "next_page"))
    if Confex.get(:video_processor, :schedule_work) == "true", do: schedule_work()
    {:noreply, state}
  end

  defp process_complex_items(complex_items, next_page) do
    Enum.each(complex_items, fn(item) -> check_state_and_run(item) end)
    if next_page != "" do
      response = next_page |> fetch_complex()
      next_page = parse_xml(response.body, "next_page")
      process_complex_items(Floki.find(response.body, "item"), next_page)
    else
      IO.puts "Process Complex Items Finished"
    end
  end

  defp fetch_complex(url, retry \\ 5) do
    case url |> HTTPoison.get([], [timeout: 60000, recv_timeout: 60000]) do
      {:ok, response} -> response
      {:error, reason} -> if retry == 0, do: raise(inspect reason), else: fetch_complex(url, retry - 1)
    end
  end

  defp schedule_work do
    IO.puts "Schedule Work"
    Process.send_after(self(), :work, 10 * 60 * 1000)
  end

  defp parse_xml(item, element) do
    result = Floki.find(item, element)
    if result |> List.first, do: result |> List.first |> elem(2) |> List.first, else: ""
  end

  def check_state_and_run(complex_media) do
    filename = parse_xml(complex_media, "guid") <> ".mp4"
    case VideoProcessor.DB.lookup(filename) do
      [] ->
        GenServer.call(VideoProcessor.Download, {:process, complex_media})
      [{filename, "download_finish"}] ->
        GenServer.call(VideoProcessor.S3Upload, {:process, complex_media})
      [{filename, "s3_upload_finish"}] ->
        GenServer.call(VideoProcessor.UplynkUpload, {:process, complex_media})
      [{filename, "done"}] -> {:ok}
    end
  end
end
