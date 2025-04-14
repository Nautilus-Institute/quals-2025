#include "deck.hpp"

uint8_t suits[] = {u8's', u8'h', u8'c', u8'd'};
uint8_t ranks[] = {u8'A', u8'2', u8'3', u8'4', u8'5', u8'6', u8'7', u8'8', u8'9', u8'X', u8'J', u8'Q', u8'K'};

uint8_t Deck::card_to_deck_number(const std::string_view& card) {
  if (card.size() != 2) {
    return UINT8_MAX;
  }

  uint8_t suit = card[0];
  uint8_t rank = card[1];

  for (uint8_t i = 0; i < 4; i++) {
    if (suit == suits[i]) {
      for (uint8_t j = 0; j < 13; j++) {
        if (rank == ranks[j]) {
          return i * 13 + j + 1;
        }
      }
    }
  }

  return UINT8_MAX;
}

std::string Deck::deck_number_to_card(uint8_t deck_number) {
  if (deck_number > 52) {
    return "";
  }

  uint8_t card[2];

  card[0] = suits[(deck_number - 1) / 13];
  card[1] = ranks[(deck_number - 1) % 13];

  return std::string(reinterpret_cast<char*>(card), 2);
}
