defmodule VideoProcessor.S3Upload do
  use GenServer

  defmodule State do
    defstruct limit: 1, current_count: 0, queue: []
  end

  def start_link do
    IO.puts "Start S3Upload"
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_state) do
    IO.puts "Init"
    {:ok, %State{}}
  end

  def handle_call({:process, source_file}, _from, state) do
    IO.puts "Upload Video to S3"
    IO.puts "Start count " <> Integer.to_string(state.current_count)
    {message, new_state} =
      if state.current_count < state.limit do
        IO.puts "Run upload"
        Task.async(VideoProcessor.S3Upload, :s3_upload, [source_file])
        {:executing_right_now, update_in(state.current_count, &(&1 + 1))}
      else
        IO.puts "Add queue"
        {:added_to_queue, update_in(state.queue, &[source_file | &1])}
      end
    IO.puts "End count " <> Integer.to_string(new_state.current_count)
    {:reply, message, new_state}
  end

  def handle_cast({:s3_upload_finish, file_name}, state) do
    IO.puts "S3 Upload Finish"
    GenServer.call(VideoProcessor.UplynkUpload, {:process, file_name})
    new_state =
      if length(state.queue) > 0 do
        [params | params_later_in_queue] = Enum.reverse(state.queue)
        Task.async(VideoProcessor.S3Upload, :s3_upload, [params])
        put_in(state.queue, params_later_in_queue)
      else
        update_in(state.current_count, &(&1 - 1))
      end
    {:noreply, new_state}
  end

  def s3_upload(file_name) do
    IO.puts "Uploading #{file_name} to S3"
    file_name
    |> ExAws.S3.Upload.stream_file
    |> ExAws.S3.upload(Application.get_env(:ex_aws, :upload_bucket), file_name)
    |> ExAws.request!
    IO.puts "Done Uploading #{file_name} to S3"
    GenServer.cast(VideoProcessor.S3Upload, {:s3_upload_finish, file_name})
  end
end
