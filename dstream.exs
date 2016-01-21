defmodule DStream do
  def unpack(bcast_proc) do
    Stream.unfold false, fn subscribed? ->
      unless subscribed? do
        send(bcast_proc, {:subscribe, self()})
        subscribed? = true
      end
      receive do
        {bcast_proc, :datum, value} -> {value, subscribed?}
        {bcast_proc, :done} -> nil
      end
    end
  end

  def pack(stream) do
    spawn_link fn ->
      broadcaster(make_stream_proc(stream), [], [], false)
    end
  end

  defp broadcaster(source, items, subs, done?) do
    #IO.puts "broadcaster(#{inspect source}, #{inspect items}, #{inspect subs})"
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

  def on_new_proc(stream) do
    unpack(pack(stream))
  end
  
  def test() do
    small? = fn x ->
      IO.puts "small? on #{inspect self()}"
      x <= 5
    end
    odd? = fn x ->
      IO.puts "odd? on #{inspect self()}"
      rem(x, 2) != 0
    end
    square = fn x ->
      IO.puts "square on #{inspect self()}"
      x * x
    end

    1..10 |>
      on_new_proc |> Stream.filter(small?) |>
      on_new_proc |> Stream.filter(odd?) |> Stream.map(square) |>
      Enum.to_list
  end
  
end
