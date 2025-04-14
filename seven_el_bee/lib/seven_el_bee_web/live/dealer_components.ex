defmodule SevenElBeeWeb.DealerComponents do
  use Phoenix.Component

  alias SevenElBee.ErraticDeck

  attr :error_list, :list

  def errors(assigns) do
    ~H"""
    <div class="errors" :if={@error_list != [] }>
      <ul>
        <li :for={error <- @error_list}>{error}</li>
      </ul>
    </div>
    """
  end

  attr :deck, ErraticDeck

  def last_card(assigns) do
    [last_card | _rest] = assigns.deck.cards
    assigns = assign(assigns, deck_number: last_card)
    card(assigns)
  end

  attr :deck_number, :integer

  def card(assigns) do
    assigns = assign(assigns, card: ErraticDeck.deck_number_to_card(assigns.deck_number))

    ~H"""
    <figure class={["card", "card-dn-#{@deck_number}", "card-#{@card}"]} data-card={@card} data-deck-number={@deck_number}>
      <img src={"/assets/images/deck/#{@deck_number}.png"} alt={@card} />
      <figcaption>{@card}</figcaption>
    </figure>
    """
  end

  attr :deck_number, :integer

  def clickable_card(assigns) do
    assigns = assign(assigns, card: ErraticDeck.deck_number_to_card(assigns.deck_number))

    ~H"""
    <button phx-click="propose_card" phx-value-deck-number={@deck_number} type="button">
      <.card deck_number={@deck_number} />
    </button>
    """
  end
end
