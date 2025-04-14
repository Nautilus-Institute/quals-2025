defmodule SevenElBeeWeb.DealerLive do
  use SevenElBeeWeb, :live_view

  alias Phoenix.LiveView.Socket
  alias SevenElBee.ErraticDeck

  import SevenElBeeWeb.DealerComponents

  import Logger, warn: false

  @want_guesses 5

  defp base_state() do
    %{
      ticket: nil,
      ticket_errors: [],
      ticket_slug: nil,
      deck: ErraticDeck.random_deck(),
      want_next_card: false,
      correct_guesses: 0,
      want_guesses: @want_guesses,
      got_wrong_guess: false,
      did_win: false,
      connected_at: NaiveDateTime.utc_now(),
      next_card: nil,
      did_guess: nil
    }
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(base_state())
      |> assign(peer_data: get_connect_info(socket, :peer_data))

    {:ok, update_deck(socket, socket.assigns.deck)}
  end

  @impl true
  def handle_event("present_ticket", %{"ticket" => candidate_ticket}, socket) do
    with ticket = %CtfTickets.Ticket{slug: slug} <-
           SevenElBee.Tickets.unpack_ticket(candidate_ticket) do
      handle_event("deal", %{}, assign(socket, ticket: ticket, ticket_slug: slug))
    else
      {:error, message} -> {:noreply, assign(socket, ticket_errors: [message])}
    end
  end

  def handle_event("rescind_ticket", _params, socket) do
    {:noreply, assign(socket, base_state())}
  end

  def handle_event("deal", _params, socket) do
    socket =
      socket
      |> assign(
        want_next_card: true,
        correct_guesses: 0,
        got_wrong_guess: false,
        did_win: false
      )
      |> update_deck(ErraticDeck.random_deck())

    {:noreply, socket}
  end

  def handle_event("propose_card", %{"deck-number" => candidate}, socket) do
    candidate = String.to_integer(candidate)
    socket = assign(socket, last_guess: candidate)
    next_deck = ErraticDeck.add_card(socket.assigns.deck)
    [got_card | _] = next_deck.cards

    cond do
      not socket.assigns.want_next_card ->
        {:noreply, socket}

      got_card == candidate ->
        socket
        |> update_deck(next_deck)
        |> handle_correct_guess()

      true ->
        socket
        |> update_deck(next_deck)
        |> handle_wrong_guess()
    end
  end

  def update_deck(socket, deck) do
    socket = assign(socket, deck: deck)

    if cheating_enabled() do
      {next_card, _rng} = ErraticDeck.draw_card(deck.rng)
      assign(socket, next_card: next_card)
    else
      socket
    end
  end

  def handle_correct_guess(socket = %Socket{assigns: %{correct_guesses: correct_guesses}})
      when correct_guesses == @want_guesses - 1 do
    flag =
      SevenElBee.Tickets.get_flag(
        socket.assigns.ticket,
        socket.assigns.peer_data.address,
        socket.assigns.connected_at
      )

    socket =
      socket
      |> assign(:want_next_card, false)
      |> assign(:correct_guesses, @want_guesses)
      |> assign(:did_win, true)
      |> assign(:flag, flag)
      |> push_event("scroll-to-top", %{})

    {:noreply, socket}
  end

  def handle_correct_guess(socket = %Socket{assigns: %{correct_guesses: guesses}}) do
    socket =
      socket
      |> assign(:correct_guesses, guesses + 1)
      |> push_event("scroll-to-top", %{})

    {:noreply, socket}
  end

  def handle_wrong_guess(socket) do
    socket =
      socket
      |> assign(:want_next_card, false)
      |> assign(:correct_guesses, 0)
      |> assign(:got_wrong_guess, true)
      |> push_event("scroll-to-top", %{})

    {:noreply, socket}
  end

  defp cheating_enabled() do
    got = Application.get_env(:seven_el_bee, SevenElBeeWeb.DealerLive)[:cheating]
    got
  end
end
