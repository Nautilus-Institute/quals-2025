#pragma once

#include <array>
#include <cstdint>
#include <istream>
#include <ostream>
#include <string>
#include <string_view>


class Deck {
  public:
  static uint8_t card_to_deck_number(const std::string_view& card);
  static std::string deck_number_to_card(uint8_t deck_number);
};


