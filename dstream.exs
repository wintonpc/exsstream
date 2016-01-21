defmodule DStream do
  def unpack(bcast_proc) do
    uniq = make_ref
    Stream.unfold false, fn subscribed? ->
      unless subscribed? do
#        IO.puts "stream unfolding on #{inspect self()} with uniq = #{inspect uniq}"
        send(bcast_proc, {:subscribe, {self(), uniq}})
        subscribed? = true
      end
      IO.puts "wait #{inspect uniq} on #{inspect self()}"
      receive do
        {_, ^uniq, {:datum, value}} ->
          IO.puts "rcvd #{value} #{inspect uniq}"
          {value, subscribed?}
        {_, ^uniq, :done} ->
          IO.puts "rcvd :done #{inspect uniq}"
          nil
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
      {^source, :item, item} ->
        broadcast([item], subs)
        broadcaster(source, [item|items], subs, done?)
      {:subscribe, sub} ->
        broadcast(Enum.reverse(items), [sub])
        if done? do
          broadcast_done([sub])
        end
        broadcaster(source, items, [sub|subs], done?)
      {^source, :done} ->
        broadcast_done(subs)
        broadcaster(source, items, subs, true)
    end
  end

  defp broadcast(items, subs) do
    Enum.each items, fn item ->
      broadcast_msg(subs, {:datum, item})
    end
  end

  defp broadcast_done(subs) do
    broadcast_msg(subs, :done)
  end
  
  defp broadcast_msg(subs, msg) do
    Enum.each subs, fn {p, uniq} ->
      IO.puts "send #{inspect msg} #{inspect(uniq)} on #{inspect p}"
      send(p, {self(), uniq, msg})
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
      IO.puts "small?(#{x}) on #{inspect self()}"
      x <= 5
    end
    odd? = fn x ->
      IO.puts "odd? on #{inspect self()}"
      rem(x, 2) != 0
    end
    square = fn x ->
      IO.puts "square(#{x}) on #{inspect self()}"
      x * x
    end
    negate = fn x ->
      IO.puts "negate(#{x}) on #{inspect self()}"
      -x
    end

    a = 2..4   |> on_new_proc # |> Stream.map(square)
    b = 12..14 |> on_new_proc # |> Stream.map(negate)

    # {Enum.to_list(a), Enum.to_list(b)}
    
    #IO.puts(inspect(Enum.to_list(a)))
    #IO.puts(inspect(Enum.to_list(b)))
    Stream.zip(a, b) |> Enum.to_list
  end
  
end
