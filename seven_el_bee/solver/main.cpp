#include <iostream>
#include <set>
#include <vector>

#include "deck.hpp"

using rng_t = unsigned int;
static_assert(sizeof(rng_t) == 4, "assumption about rng_t is not 4 bytes");

using card_t = unsigned char;
static_assert(sizeof(card_t) == 1, "assumption about card_t is not 1 byte");

const int initial_sweep = 4;
const int want_at_least = 32;
const int generate_to = 60;
static_assert(want_at_least >= initial_sweep, "want_at_least must be gteq initial_sweep");

// cross reference constants with `chall_rng.ex`
rng_t modulus = 2'147'483'648;
rng_t multiplier = 134'775'813;
rng_t increment = 1'337;

rng_t rng(rng_t seed) {
  return ((multiplier * seed)+ increment) % modulus;
}

// cross reference algo with `erratic_deck.ex`
card_t rng_to_card(rng_t rng) {
  return ((rng & 0x3f) % 52) + 1;
}

std::set<rng_t> check_first_few(const std::vector<card_t>& deck) {
  std::set<rng_t> seeds;

  for (rng_t candidate_seed = 0; candidate_seed < modulus; candidate_seed++) {
    // bool be_noisy = false;
    // if (candidate_seed == 1355268914) be_noisy = true;
    bool found = true;
    rng_t state = candidate_seed;
    for (int i = 0; i < initial_sweep; i++) {
      state = rng(state);
      card_t card = rng_to_card(state);
      // if (be_noisy) {
      //   std::cout << std::endl << 
      //     state << " " << 
      //     card << " " << 
      //     Deck::deck_number_to_card(card) << std::endl;
      // }
      if (card != deck[i]) {
          found = false;
          break;
      }
    }

    if (found) {
        seeds.insert(candidate_seed);
    }

    if (candidate_seed % 0x1000000 == 0) {
        std::cout << "\r" << std::hex << candidate_seed << std::flush;
    }
  }

  return seeds;
}

bool check_full(rng_t seed, const std::vector<card_t>& deck) {
  rng_t state = seed;
  for (int i = 0; i < deck.size(); i++) {
    state = rng(state);
    card_t card = rng_to_card(state);
    if (card != deck[i]) {
        return false;
    }
  }

  return true;
}

int main() {
  // rng_t demo = 1355268914;
  // for (int i = 0; i < 52; i++) {
  //   std::cout << demo << " " << Deck::deck_number_to_card(rng_to_card(demo)) << std::endl;
  //   demo = rng(demo);
  // }

    std::cout << "paste cards, `ZZ` after last card" << std::endl;

    std::vector<card_t> cards;

    while (true) {
        std::string card;
        std::cin >> card;

        if (card == "ZZ") {
            break;
        }

        if (card.size() != 2) {
            std::cerr << "invalid card" << std::endl;
            continue;
        }

        cards.push_back(Deck::card_to_deck_number(card));
    }

    std::cout << "got " << cards.size() << " cards" << std::endl;

    bool all_cards_were_doubled = true;

    for (int i = 0; i < (cards.size() - 1); i+= 2) {
        if (cards[i] != cards[i + 1]) {
            all_cards_were_doubled = false;
            break;
        }
    }

    if (all_cards_were_doubled) {
        std::cout << "all cards were doubled" << std::endl;
        for (int i = 0; i < (cards.size() / 2); i++) {
          card_t found = cards[i * 2];
          cards[i] = found;
        }
        cards.resize(cards.size() / 2);
    } else {
        std::cout << "not all cards were doubled" << std::endl;
    }

    if (cards.size() < want_at_least) {
        std::cerr << "not enough cards" << std::endl;
        return 1;
    }

    for (int i = 0; i < cards.size(); i++) {
        std::cout << Deck::deck_number_to_card(cards[i]) << " ";
    }
    std::cout << std::endl;

    std::set<rng_t> swept_seeds = check_first_few(cards);
    if (swept_seeds.size() == 0) {
        std::cout << "no seeds found" << std::endl;
        return 1;
    } else {
        std::cout << "check_first_few found " << swept_seeds.size() << " seeds" << std::endl;
    }

    std::set<rng_t> validated_seeds;
    for (rng_t seed : swept_seeds) {
        bool found = check_full(seed, cards);

        if (found) {
            validated_seeds.insert(seed);
        }
    }

    if (validated_seeds.size() == 0) {
        std::cout << "no seeds validated" << std::endl;
        return 1;
    } else {
        std::cout << "validated seeds: " << validated_seeds.size() << std::endl;
    }

    rng_t first_seed = *validated_seeds.begin();
    for (int i = 0; i < generate_to; i++) {
        first_seed = rng(first_seed);
        card_t card = rng_to_card(first_seed);
        std::cout << Deck::deck_number_to_card(card) << " ";
    }

    std::cout << std::endl;

    return 0;
}