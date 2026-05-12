defmodule UtilsTest do
  use ExUnit.Case
  doctest ConfigServer.Utils
  alias ConfigServer.Utils

  test "parse directory" do
    expected = %{
      "top" => %{"foo" => "bar"},
      "top.txt" => "foobar\n",
      "nested" => %{
        "another" => %{"bar" => 42},
        "something.txt" => "at the end of the universe\n"
      }
    }
    assert expected == Utils.parse_directory("./test/test_dir")
  end

end
