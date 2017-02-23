defmodule VideoProcessor.DB do
  def insert(filename, status) do
    storage = Confex.get(:video_processor, :disk_storage)
    :dets.open_file(storage, [type: :set])
    result = :dets.insert(storage, {filename, status})
    :dets.close(storage)
    result
  end

  def lookup(filename) do
    storage = Confex.get(:video_processor, :disk_storage)
    :dets.open_file(storage, [type: :set])
    result = :dets.lookup(storage, filename)
    :dets.close(storage)
    result
  end
end
