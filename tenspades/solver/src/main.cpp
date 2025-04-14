#include <iostream>

#include "chall_rng.hpp"
#include "deck.hpp"

const std::string maybe_get_env(const std::string env_name, const std::string default_value);

static_assert(sizeof(unsigned long long) >= sizeof(ChallRng::result_type));

int main()
{
  std::cout << "deal seed pls: " << std::endl;
  ChallRng::result_type deal_seed;
  std::cin >> std::hex >> deal_seed;
  
  std::cout << "deck: " << std::endl;
  Deck deck;
  std::cin >> deck;

  ChallRng::result_type candidate_seed;
  bool did_find = false;

  for (candidate_seed = 0; 
    candidate_seed < mersenne_31; 
    candidate_seed++) {

    if (candidate_seed % 0x1000000 == 0) {
      std::cout << "\r" << std::hex << candidate_seed << std::flush;
    }

    ChallRng rng = ChallRng(candidate_seed, deal_seed);
    Deck ours = Deck(rng);

    if (deck == ours) {
      std::cout << "\nFound candidate team seed: " << std::hex << candidate_seed << std::endl;
      did_find = true;
      break;
    }
  }

  if (! did_find) {
    std::cout << "Failed to find candidate team seed, rip" << std::endl;
    return 1;
  }

  std::cout << "new deal seed: " << std::endl;
  ChallRng::result_type solve_deal_seed;
  std::cin >> std::hex >> solve_deal_seed;

  ChallRng rng = ChallRng(candidate_seed, solve_deal_seed);
  Deck solved = Deck(rng);

  std::cout << "solved deck: " << std::endl <<
    solved << std::endl;

  return 0;
}

const std::string maybe_get_env(const std::string env_name, const std::string default_value)
{
  char *env_value = std::getenv(env_name.c_str());

  if (env_value)
  {
    return std::string(env_value);
  }
  return default_value;
}
