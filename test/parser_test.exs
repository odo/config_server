defmodule ParserTest do
  use ExUnit.Case
  doctest ConfigServer.Parser
  alias ConfigServer.Parser

  test "parse directory" do
    expected = %{
      "top" => %{"foo" => "bar"},
      "top.txt" => "foobar\n",
      "nested" => %{
        "another" => %{"bar" => 42},
        "something.txt" => "at the end of the universe\n"
      }
    }
    assert expected == Parser.parse_directory("./test/test_dir")
  end

end
