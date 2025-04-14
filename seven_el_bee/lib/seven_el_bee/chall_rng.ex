defmodule SevenElBee.ChallRng do
  @type rng_int :: 0..0xFFFFFFFF

  @modulus 2_147_483_648
  @multiplier 134_775_813
  @increment 1337

  @type t :: %__MODULE__{
          state: rng_int()
        }
  defstruct state: 0

  @doc ~S"""
    Make a new RNG with a given or random seed

    ## Examples

    iex> SevenElBee.ChallRng.new(42)
    %SevenElBee.ChallRng{state: 42}
    iex> SevenElBee.ChallRng.new() == SevenElBee.ChallRng.new()
    false
  """
  @spec new(rng_int()) :: t
  def new(seed) do
    %__MODULE__{state: seed}
  end

  @spec new() :: t
  def new() do
    new(random_seed())
  end

  @doc ~S"""
    Convert an RNG to an integer seed

    ## Examples

    iex> rng = SevenElBee.ChallRng.new(42)
    iex> SevenElBee.ChallRng.to_seed_integer(rng)
    42
  """
  @spec to_seed_integer(t()) :: rng_int()
  def to_seed_integer(%__MODULE__{state: state}) do
    state
  end

  @doc ~S"""
    Get the next random number and the new RNG state

    ## Examples

    iex> rng = SevenElBee.ChallRng.new(42)
    iex> {got, new_rng} = SevenElBee.ChallRng.next(rng)
    iex> got
    1365618187
    iex> new_rng
    %SevenElBee.ChallRng{state: 1365618187}
  """
  @spec next(t()) :: {rng_int(), t()}
  def next(%__MODULE__{state: state} = rng) do
    next_state =
      Integer.mod(
        @multiplier * state + @increment,
        @modulus
      )

    {next_state, %__MODULE__{rng | state: next_state}}
  end

  defp random_seed() do
    wanted_bytes =
      @modulus
      # bits
      |> :math.log2()
      # more bits
      |> Kernel.ceil()
      # bytes
      |> Kernel./(8)
      # more bytes
      |> Kernel.ceil()

    <<seed::wanted_bytes*8>> = :crypto.strong_rand_bytes(wanted_bytes)

    Integer.mod(seed, @modulus)
  end
end
