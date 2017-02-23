defmodule VideoProcessor.UplynkUpload do
  use GenServer

  defmodule State do
    defstruct limit: Confex.get(:video_processor, :task_limit), current_count: 0, queue: []
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_state) do
    {:ok, %State{}}
  end

  def handle_call({:process, complex_media}, _from, state) do
    {message, new_state} =
      if state.current_count < state.limit do
        Task.start(VideoProcessor.UplynkUpload, :uplynk_upload, [complex_media])
        {:executing_right_now, update_in(state.current_count, &(&1 + 1))}
      else
        {:added_to_queue, update_in(state.queue, &[complex_media | &1])}
      end
    {:reply, message, new_state}
  end

  def handle_cast({:uplynk_upload_finish, filename}, state) do
    VideoProcessor.DB.insert(filename, "done")
    download_dir = Confex.get(:video_processor, :download_dir)
    File.rm(download_dir <> "/" <> filename)
    new_state =
      if length(state.queue) > 0 do
        [params | params_later_in_queue] = Enum.reverse(state.queue)
        if VideoProcessor.DB.lookup(filename) == [{filename, "s3_upload_finish"}] do
          Task.start(VideoProcessor.UplynkUpload, :uplynk_upload, [params])
        end
        put_in(state.queue, params_later_in_queue)
      else
        update_in(state.current_count, &(&1 - 1))
      end
    {:noreply, new_state}
  end

  def uplynk_upload(complex_media) do
    filename = parse_xml(complex_media, "guid") <> ".mp4"
    poster_file = get_thumbnail(complex_media)
    IO.puts "Uploading #{filename} to upLynk"
    msg = %{
      "_owner"      => Confex.get(:video_processor, :uplynk_account_guid),
      "_timestamp"  => DateTime.utc_now() |> DateTime.to_unix,
      "source"      => %{
        url: Confex.get(:video_processor, :s3_url) <> Confex.get(:ex_aws, :upload_folder) <> "#{filename}",
        api_key: Confex.get(:ex_aws, :access_key_id),
        api_secret: Confex.get(:ex_aws, :secret_access_key)
      },
      "args"        => %{
        external_id: String.replace(filename, ".mp4", ""),
        poster_file: poster_file,
        skip_drm:    1,
        meta: "complex_category=#{parse_xml(complex_media, "media|category")},,,complex_account=#{parse_xml(complex_media, "account")}"
      }
    }
    uplynk_get("cloudslicer/jobs/create", msg)
    IO.puts "Done Uploading #{filename} to upLynk"
    GenServer.cast(VideoProcessor.UplynkUpload, {:uplynk_upload_finish, filename})
  end

  defp parse_xml(item, element) do
    Floki.find(item, element) |> List.first |> elem(2) |> List.first
  end

  defp get_thumbnail(item) do
    Floki.find(item, "media|thumbnail") |> List.first |> elem(1) |> List.first |> elem(1)
  end

  defp uplynk_get(link, msg) do
    msg = msg |> JSX.encode |> elem(1)
    msg = Base.encode64(:zlib.compress(msg)) |> String.strip
    sig = :crypto.hmac(:sha256, Confex.get(:video_processor, :uplynk_secret_key), msg) |> Base.encode16
    query = %{msg: msg, sig: sig} |> URI.encode_query
    HTTPoison.get!("http://services.uplynk.com/api2/" <> link <> "?" <> query)
  end
end
