#pragma once

#include <array>
#include <cstdint>
#include <istream>
#include <ostream>
#include <string>
#include <string_view>

#include "chall_rng.hpp"

class Deck {
  public:
  static uint8_t card_to_deck_number(const std::string_view& card);
  static std::string deck_number_to_card(uint8_t deck_number);

  Deck();
  Deck(ChallRng& rng);

  friend std::ostream& operator<<(std::ostream& os, const Deck& deck);
  friend std::istream& operator>>(std::istream& is, Deck& deck);

  bool operator==(const Deck& other) const;

  const static uint8_t card_count = 52;

  private:
  std::array<uint8_t, card_count> cards;
};


