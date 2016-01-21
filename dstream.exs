defmodule DStream do
  def unpack(bcast_proc) do
    uniq = make_ref
    Stream.unfold false, fn subscribed? ->
      unless subscribed? do
        send(bcast_proc, {:subscribe, {self(), uniq}})
        subscribed? = true
      end
      receive do
        {^uniq, {:datum, value}} -> {value, subscribed?}
        {^uniq, :done} -> nil
      end
    end
  end

  def pack(stream) do
    spawn_link fn ->
      broadcaster(make_stream_proc(stream), [], [], false)
    end
  end

  defp broadcaster(source, items, subs, done?) do
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
      send(p, {uniq, msg})
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

  def div(stream) do
    unpack(pack(stream))
  end
  
  def test() do
    small? = fn x ->
      trace("small?", x)
      x <= 5
    end
    odd? = fn x ->
      trace("odd?", x)
      rem(x, 2) != 0
    end
    square = fn x ->
      trace("square", x)
      x * x
    end
    negate = fn x ->
      trace("negate", x)
      -x
    end
    to_s = fn x ->
      trace("to_s", x)
      inspect(x)
    end

    n = Stream.unfold(1, up_to(3)) |> div
    a = n |> Stream.map(square) |> div
    b = n |> Stream.map(negate) |> div
    c = Stream.zip(a, b) |> div
    d = c |> Stream.map(to_s)
    Enum.to_list(d)
  end

  def up_to(max) do
    fn next ->
      if next <= max do
        trace("generate", next)
        {next, next+1}
      else
        nil
      end
    end
  end

  defp trace(name, arg) do
    IO.puts "#{name}(#{inspect arg}) on #{inspect self()}"
  end
  
end
