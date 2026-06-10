defmodule ConfigServer.Parser do
  def parse_directory(path) do
      path
      |> File.ls!()
      |> Enum.map(
        fn(entry) ->
          full_path = Path.join(path, entry)
          case {is_ignored?(entry), File.dir?(full_path), String.ends_with?(entry, ".json")} do
            {true, _,    _}    -> nil
            {_,    true, _}    -> {entry, parse_directory(full_path)}
            {_,    _,   true} ->  {Path.rootname(entry), JSON.decode!(File.read!(full_path))}
            {_,    _,   false} -> {entry, File.read!(full_path)}
          end
        end
      )
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})
  end

  defp is_ignored?(entry) do
    String.starts_with?(entry, ".")
    || String.match?(entry, ~r/^readme/i)
    || String.match?(entry, ~r/^license/i)
  end
end
