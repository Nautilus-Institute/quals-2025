defmodule SevenElBeeWeb.DealerLiveTest do
  use SevenElBeeWeb.ConnCase

  alias Phoenix.LiveView.Socket
  alias SevenElBeeWeb.DealerLive
  alias SevenElBee.Tickets
  alias SevenElBee.ErraticDeck

  import Phoenix.LiveViewTest, warn: false
  import Phoenix.Component, only: [assign: 2]

  setup do
    {:ok,
     ticket:
       "ticket{22weatherdeckweatherdeckweatherdeck143032:fvhGh-7jS1MsxxF4YlB74MPdWSKZl0clNAmCKO8HgkcA6jN9}"}
  end

  test "accepts a ticket", %{ticket: ticket} do
    {:noreply, socket} =
      DealerLive.handle_event("present_ticket", %{"ticket" => "bepis"}, %Socket{})

    assert socket.assigns.ticket_errors == ["couldn't parse"]

    {:noreply, socket} =
      DealerLive.handle_event("present_ticket", %{"ticket" => ticket}, %Socket{})

    assert socket.assigns.ticket == Tickets.unpack_ticket(ticket)
  end

  test "deals a new hand" do
    {:noreply, socket} = DealerLive.handle_event("deal", %{}, %Socket{})
    assert %ErraticDeck{cards: cards, rng: _rng} = socket.assigns.deck
    assert is_list(cards)
    assert length(cards) == 52

    {:noreply, socket} = DealerLive.handle_event("deal", %{}, %Socket{})
    assert %ErraticDeck{cards: new_cards, rng: _new_rng} = socket.assigns.deck
    assert new_cards != cards
  end

  test "rejects a wrong guess for the next card", %{ticket: ticket} do
    {:noreply, socket} =
      DealerLive.handle_event("present_ticket", %{"ticket" => ticket}, %Socket{})

    rng = socket.assigns.deck.rng
    {card, _new_rng} = ErraticDeck.draw_card(rng)
    # should be 4 off
    wrong_card = rem(card + 5, 52) + 1

    {:noreply, socket} =
      DealerLive.handle_event(
        "propose_card",
        %{"deck-number" => Integer.to_string(wrong_card)},
        socket
      )

    assert socket.assigns.got_wrong_guess
    assert nil == socket.assigns[:flag]
    assert !socket.assigns[:did_win]
  end

  test "accepts a correct guess for the next card", %{ticket: ticket} do
    {:noreply, socket} =
      DealerLive.handle_event("present_ticket", %{"ticket" => ticket}, %Socket{})

    socket = assign(socket, correct_guesses: 0)
    rng = socket.assigns.deck.rng
    {card, _new_rng} = ErraticDeck.draw_card(rng)

    {:noreply, socket} =
      DealerLive.handle_event("propose_card", %{"deck-number" => Integer.to_string(card)}, socket)

    assert !socket.assigns.got_wrong_guess
    assert nil == socket.assigns[:flag]
    assert !socket.assigns[:did_win]
    assert 1 == socket.assigns[:correct_guesses]
  end

  test "dispenses a flag after five guesses", %{ticket: ticket} do
    {:noreply, socket} =
      DealerLive.handle_event("present_ticket", %{"ticket" => ticket}, %Socket{})

    socket =
      assign(socket,
        correct_guesses: 4,
        peer_data: %{port: 420, address: {10, 10, 4, 20}, ssl_cert: nil},
        connected_at: NaiveDateTime.utc_now()
      )

    rng = socket.assigns.deck.rng
    {card, _new_rng} = ErraticDeck.draw_card(rng)

    {:noreply, socket} =
      DealerLive.handle_event("propose_card", %{"deck-number" => Integer.to_string(card)}, socket)

    assert !socket.assigns.got_wrong_guess
    assert is_binary(socket.assigns[:flag])
    assert socket.assigns[:did_win]
  end
end
