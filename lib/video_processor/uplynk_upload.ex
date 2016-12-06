defmodule VideoProcessor.UplynkUpload do
  use GenServer

  defmodule State do
    defstruct limit: 1, current_count: 0, queue: []
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_state) do
    {:ok, %State{}}
  end

  def handle_call({:process, source_file}, _from, state) do
    {message, new_state} =
      if state.current_count < state.limit do
        Task.async(VideoProcessor.UplynkUpload, :uplynk_upload, [source_file])
        {:executing_right_now, update_in(state.current_count, &(&1 + 1))}
      else
        {:added_to_queue, update_in(state.queue, &[source_file | &1])}
      end
    {:reply, message, new_state}
  end

  def handle_cast(:uplynk_upload_finish, state) do
    new_state =
      if length(state.queue) > 0 do
        [params | params_later_in_queue] = Enum.reverse(state.queue)
        Task.async(VideoProcessor.UplynkUpload, :uplynk_upload, [params])
        put_in(state.queue, params_later_in_queue)
      else
        update_in(state.current_count, &(&1 - 1))
      end
    {:noreply, new_state}
  end

  def uplynk_upload(file_name) do
    IO.puts "Uploading #{file_name} to upLynk"
    msg = %{
      "_owner"      => Confex.get(:video_processor, :uplynk_account_guid),
      "_timestamp"  => DateTime.utc_now() |> DateTime.to_unix,
      "source"      => %{
        url: Confex.get(:video_processor, :s3_url) <> "/#{file_name}",
        api_key: Confex.get(:ex_aws, :access_key_id),
        api_secret: Confex.get(:ex_aws, :secret_access_key)
      },
      "args"        => %{external_id: String.replace(file_name, ".mp4", "")}
    } |> JSX.encode |> elem(1)
    msg = Base.encode64(:zlib.compress(msg)) |> String.strip
    sig = :crypto.hmac(:sha256, Application.fetch_env!(:video_processor, :uplynk_secret_key), msg) |> Base.encode16
    query = %{msg: msg, sig: sig} |> URI.encode_query
    HTTPoison.get!("http://services.uplynk.com/api2/cloudslicer/jobs/create?" <> query)
    IO.puts "Done Uploading #{file_name} to upLynk"
    GenServer.cast(VideoProcessor.UplynkUpload, :uplynk_upload_finish)
  end

  def get_cloud_jobs do
    msg = %{
      "_owner"      => Confex.get(:video_processor, :uplynk_account_guid),
      "_timestamp"  => DateTime.utc_now() |> DateTime.to_unix
    } |> JSX.encode |> elem(1)
    msg = Base.encode64(:zlib.compress(msg)) |> String.strip
    sig = :crypto.hmac(:sha256, Confex.get(:video_processor, :uplynk_secret_key), msg) |> Base.encode16
    query = %{msg: msg, sig: sig} |> URI.encode_query
    response = HTTPoison.get!("http://services.uplynk.com/api2/cloudslicer/jobs/list?" <> query)
    IO.puts inspect response
  end
end
