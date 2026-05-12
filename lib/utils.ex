defmodule ConfigServer.Utils do
  def parse_directory(path) do
      path
      |> File.ls!()
      |> Enum.map(
        fn(entry) ->
          full_path = Path.join(path, entry)
          case File.dir?(full_path) do
            true ->
              {entry, parse_directory(full_path)}
            false ->
              case {String.starts_with?(entry, "."), String.ends_with?(entry, ".json")} do
                {true, _} -> nil
                {_, true} ->  {Path.rootname(entry), JSON.decode!(File.read!(full_path))}
                {_, false} -> {entry, File.read!(full_path)}
              end
          end
        end
      )
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})
  end
end
