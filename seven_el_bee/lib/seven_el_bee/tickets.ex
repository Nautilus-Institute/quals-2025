defmodule SevenElBee.Tickets do
  import Logger, warn: false

  alias CtfTickets.Ticket
  alias CtfTickets.Receipt

  def unpack_ticket(encrypted_ticket) when is_binary(encrypted_ticket) do
    case Ticket.deserialize(challenge_secret_key(), encrypted_ticket) do
      {:error, reason} -> {:error, reason}
      ticket = %Ticket{} -> ticket
    end
  end

  def get_flag(ticket = %Ticket{}, ip_address, connected_at \\ NaiveDateTime.utc_now()) do
    Receipt.initialize(challenge_secret_key(), ticket, ip_address, connected_at)
    |> Receipt.serialize()
  end

  defp challenge_secret_key() do
    Application.get_env(:seven_el_bee, SevenElBee.Tickets)[:challenge_secret_key]
  end
end
