defmodule Pictionary.Stores.GameStore do
  use GenServer
  alias Pictionary.Game
  require Logger

  @table_name :game_table
  @custom_word_limit 10000

  @permitted_update_params [
    "id",
    "rounds",
    "time",
    "max_players",
    "custom_words",
    "custom_words_probability",
    "public_game",
    "vote_kick_enabled"
  ]

  ## Public API

  def get_game(game_id) do
    case GenServer.call(__MODULE__, {:get, game_id}) do
      [{_id, {:set, game}}] -> game
      [{_game_id, game_data}] -> game_data
      _ -> nil
    end
  end

  def add_game(game) do
    GenServer.call(__MODULE__, {:set, game})
  end

  def update_game(game_params) do
    GenServer.call(__MODULE__, {:update, game_params})
  end

  def add_player(game_id, player_id) do
    GenServer.call(__MODULE__, {:add_player, game_id, player_id})
  end

  def remove_player(game_id, player_id) do
    GenServer.call(__MODULE__, {:remove_player, game_id, player_id})
  end

  ## GenServer callbacks

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    # Create a ETS table
    # private access ensure read/write limited to owner process.
    :ets.new(@table_name, [:named_table, :set, :private])

    {:ok, nil}
  end

  def handle_call({:get, game_id}, _from, state) do
    game = :ets.lookup(@table_name, game_id)
    {:reply, game, state}
  end

  def handle_call({:set, %Game{id: game_id}} = game_data, _from, state) do
    # Below pattern match ensure genserver faliure and restart in case
    # of ETS insertion faliure
    true = :ets.insert(@table_name, {game_id, game_data})

    Logger.info("Create game #{game_id}")

    {:reply, game_data, state}
  end

  def handle_call({:update, %{"id" => id} = game_params}, _from, state) do
    # For some reason :ets is returning two types of values, this case block handles both
    game = fetch_game(id)

    updated_game =
      if game do
        filtered_params =
          game_params
          |> Enum.filter(fn {key, _val} -> Enum.find(@permitted_update_params, &(&1 == key)) end)
          |> Enum.map(fn {key, val} -> {String.to_atom(key), val} end)
          |> Enum.into(%{})
          |> handle_custom_words()

        updated_game = struct(game, Map.put(filtered_params, :updated_at, DateTime.utc_now()))

        true = :ets.insert(@table_name, {id, updated_game})

        Logger.info("Update game #{id}")

        updated_game
      end

    {:reply, updated_game || game, state}
  end

  def handle_call({:add_player, game_id, player_id}, _from, state) do
    game = fetch_game(game_id)

    if game do
      game = %Pictionary.Game{game | players: MapSet.put(game.players, player_id)}
      true = :ets.insert(@table_name, {game_id, game})
      Logger.info("Add player #{player_id} to game #{game_id}")
      {:reply, game, state}
    else
      {:reply, :error, state}
    end
  end

  def handle_call({:delete_player, game_id, player_id}, _from, state) do
    game = fetch_game(game_id)

    if game do
      game = %Pictionary.Game{game | players: MapSet.delete(game.players, player_id)}
      true = :ets.insert(@table_name, {game_id, game})
      Logger.info("Removed player #{player_id} from game #{game_id}")
      {:reply, game, state}
    else
      {:reply, :error, state}
    end
  end

  ## Private helpers

  defp handle_custom_words(%{custom_words: custom_words} = filtered_params) do
    custom_word_list =
      custom_words
      |> String.split(",")
      |> Stream.map(fn word ->
        word
        |> String.downcase()
        |> String.trim()
      end)
      |> Stream.filter(&(String.length(&1) < 30 || String.length(&1) > 2))
      |> Stream.uniq()
      |> Enum.take(@custom_word_limit)

    Map.put(filtered_params, :custom_words, custom_word_list)
  end

  defp handle_custom_words(filtered_params), do: filtered_params

  defp fetch_game(game_id) do
    case :ets.lookup(@table_name, game_id) do
      [{_id, {:set, game}}] -> game
      [{_game_id, game}] -> game
      _ -> nil
    end
  end
end
