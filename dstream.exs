defmodule DStream do
  def stream_from(p) do
    send(p, {:register, self()})
    Stream.unfold(nil, fn _ ->
      IO.puts "unfold requested a value"
      receive do
        {:data, value} ->
          IO.puts "providing value: #{value}"
          {value, nil}
        :done ->
          IO.puts "done, signaling end of stream"
          nil
      end
    end)
  end

  def of(stream) do
    spawn fn ->
      IO.puts "gathering subscribers"
      subs = gather_subscribers([])
      IO.puts "pushing stream"
      push_stream(stream, subs)
    end
  end

  def unleash(dstreams) do
    Enum.each(dstreams, fn ds -> send(ds, :start) end)
  end
  
  defp gather_subscribers(subs) do
    receive do
      {:register, s} -> gather_subscribers([s|subs])
      :start -> subs
    end
  end

  defp push_stream(stream, subs) do
    Enum.each(stream, fn value -> multicast({:data, value}, subs) end)
    multicast(:done, subs)
  end

  defp multicast(msg, subs) do
    Enum.each(subs, fn sub -> send(sub, msg) end)
  end

  def test() do
    source = DStream.of(1..5)
    reader = DStream.stream_from(source)
    DStream.unleash([source])
    odd? = &(rem(&1, 2) != 0)
    reader |> Stream.filter(odd?) |> Enum.to_list
  end
  
end
