defmodule SevenElBee.ErraticDeck do
  @type deck_number :: 1..52

  @type t :: %__MODULE__{
          cards: [deck_number()],
          rng: SevenElBee.ChallRng.t()
        }
  defstruct cards: [], rng: %SevenElBee.ChallRng{}

  @suits "shcd"
  @ranks "A23456789XJQK"

  alias SevenElBee.ChallRng

  import Logger, warn: false

  @doc ~S"""
    Create an empty deck

    iex> ErraticDeck.empty_deck()
    %SevenElBee.ErraticDeck{cards: [], rng: %SevenElBee.ChallRng{state: 0}}
  """
  def empty_deck() do
    %SevenElBee.ErraticDeck{}
  end

  @doc ~S"""
    Make a deck with an rng

    iex> ErraticDeck.random_deck(%SevenElBee.ChallRng{state: 42})
    %SevenElBee.ErraticDeck{cards: [23, 6, 1, 28, 7, 14, 5, 16, 31, 34, 9, 4,
      3, 2, 13, 4, 39, 10, 17, 44, 11, 30, 21, 32, 47, 50, 25, 20, 19, 6, 29,
      8, 3, 26, 33, 8, 27, 46, 37, 48, 11, 2, 41, 36, 35, 22, 45, 24, 7,
      42, 49, 12], rng: %SevenElBee.ChallRng{state: 1780571670}}
  """
  def random_deck(), do: random_deck(ChallRng.new())

  def random_deck(initial_rng = %ChallRng{}) do
    initial = %SevenElBee.ErraticDeck{rng: initial_rng}

    # Logger.info([initial: initial.rng.state])

    add_card(initial, 52)
  end

  def add_card(deck) do
    add_card(deck, 1)
  end

  def add_card(deck, 0), do: deck

  def add_card(%__MODULE__{cards: cards, rng: rng}, count) do
    {card, rng} = draw_card(rng)
    # Logger.info([initial: rng.state])
    add_card(%__MODULE__{cards: [card | cards], rng: rng}, count - 1)
  end

  @doc """
  Cooks a deck to an output string

  iex> deck = ErraticDeck.random_deck(%SevenElBee.ChallRng{state: 42})
  iex> ErraticDeck.to_string(deck)
  "hX s6 sA c2 s7 hA s5 h3 c5 c8 s9 s4 s3 s2 sK s4 cK sX h4 d5 sJ c4 h8 c6 d8 dJ hQ h7 h6 s6 c3 s8 s3 hK c7 s8 cA d7 cJ d9 sJ s2 d2 cX c9 h9 d6 hJ s7 d3 dX sQ"
  """
  def to_string(deck) do
    Enum.map(deck.cards, &deck_number_to_card/1)
    |> Enum.join(" ")
  end

  @doc """
  Draw a single card from an rng

  iex> ErraticDeck.draw_card(%SevenElBee.ChallRng{state: 42})
  {12, %SevenElBee.ChallRng{state: 1365618187}}
  """
  def draw_card(rng = %ChallRng{}) do
    {maybe_card, rng} = ChallRng.next(rng)

    card =
      maybe_card
      |> Bitwise.&&&(0x3F)
      |> Integer.mod(52)
      |> Kernel.+(1)

    {card, rng}
  end

  @doc ~S"""
    Convert a deck number to a string representing a card

    iex> ErraticDeck.deck_number_to_card(1)
    "sA"
    iex> ErraticDeck.deck_number_to_card(13)
    "sK"
    iex> ErraticDeck.deck_number_to_card(14)
    "hA"
    iex> ErraticDeck.deck_number_to_card(52)
    "dK"
    iex> ErraticDeck.deck_number_to_card(-1)
    :error
    iex> ErraticDeck.deck_number_to_card(53)
    :error
  """
  def deck_number_to_card(deck_number) when deck_number in 1..52 do
    suit_i = div(deck_number - 1, 13)
    rank_i = rem(deck_number - 1, 13)
    <<:binary.at(@suits, suit_i), :binary.at(@ranks, rank_i)>>
  end

  def deck_number_to_card(_), do: :error

  @doc ~S"""
    Convert a card string to a deck number

    iex> ErraticDeck.card_to_deck_number("sA")
    1
    iex> ErraticDeck.card_to_deck_number("sK")
    13
    iex> ErraticDeck.card_to_deck_number("hA")
    14
    iex> ErraticDeck.card_to_deck_number("dK")
    52
    iex> ErraticDeck.card_to_deck_number("bepis")
    :error
  """
  def card_to_deck_number(card) do
    with suit_idx when is_integer(suit_idx) <- find_idx(@suits, :binary.at(card, 0)),
         rank_idx when is_integer(rank_idx) <- find_idx(@ranks, :binary.at(card, 1)) do
      suit_idx * 13 + rank_idx + 1
    else
      _ -> :error
    end
  end

  defp find_idx(binstr, char), do: find_idx(binstr, char, 0)

  defp find_idx(<<>>, _, _), do: nil
  defp find_idx(<<char, _rest::binary>>, char, idx), do: idx
  defp find_idx(<<_, rest::binary>>, char, idx), do: find_idx(rest, char, idx + 1)
end
