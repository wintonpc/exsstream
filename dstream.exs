defmodule DStream do
  def unpack(p) do
    send(p, {:register, self()})
    Stream.unfold(nil, fn _ ->
      receive do
        {:data, value} ->
          IO.puts "got value: #{value}"
          {value, nil}
        :done -> nil
      end
    end)
  end

  def pack(stream) do
    spawn_link fn ->
      broadcaster(make_stream_proc(stream), [], [], false)
    end
  end

  defp broadcaster(source, items, subs, done?) do
    IO.puts "broadcaster(#{inspect source}, #{inspect items}, #{inspect subs})"
    receive do
      {source, :item, item} ->
        broadcast([item], subs)
        broadcaster(source, [item|items], subs, done?)
      {:subscribe, sub} ->
        broadcast(Enum.reverse(items), [sub])
        if done? do
          broadcast_done([sub])
        end
        broadcaster(source, items, [sub|subs], done?)
      {source, :done} ->
        broadcast_done(subs)
        broadcaster(source, items, subs, true)
    end
  end

  defp broadcast(items, subs) do
    Enum.each items, fn item ->
      broadcast_msg(subs, {self(), :datum, item})
    end
  end

  defp broadcast_done(subs) do
    broadcast_msg(subs, {self(), :done})
  end
  
  defp broadcast_msg(subs, msg) do
    Enum.each subs, fn sub ->
      send(sub, msg)
    end
  end

  def make_stream_proc(stream) do
    client = self()
    spawn fn ->
      Enum.each stream, fn x ->
        send(client, {self(), :item, x})
      end
      send(client, {self(), :done})
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
    IO.puts "multicast #{inspect msg}"
    Enum.each(subs, fn sub -> send(sub, msg) end)
  end

  def test() do
    odd? = &(rem(&1, 2) != 0)

    source = pack(1..5)
    reader = unpack(pack(Stream.filter(unpack(source), odd?)))
    DStream.unleash([source])
    reader |> Enum.to_list
  end
  
end
