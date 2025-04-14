#include <fstream>
#include <iostream>

#include "chall_rng.hpp"
#include "deck.hpp"

const std::string get_flag();
const std::string maybe_get_env(const std::string env_name, const std::string default_value);

static_assert(sizeof(unsigned long long) >= sizeof(ChallRng::result_type));

int main()
{
  std::string env_seed_s = maybe_get_env("SEED", "1337");
  ChallRng::result_type team_seed = std::stoull(env_seed_s) & UINT32_MAX;

  ChallRng::result_type given_seed;

  std::cout << "tenspades" << std::endl;
  std::cout << Deck() << std::endl;

  while (true)
  {
    if ((! std::cout.good()) || (! std::cin.good()))
    {
      return 0;
    }

    // team_seed provides the rng params, the seed comes from a random_device
    ChallRng rng(team_seed);
    given_seed = rng.next();

    std::cout << "seed: " << std::hex << given_seed << std::endl;

    Deck ours(rng);

#ifdef CHEAT
    std::cerr << "cheat " << ours << std::endl;
#endif

    std::cout << "show me your cards " << std::endl;

    Deck player{};
    std::cin >> player;

    if (ours == player)
    {
      std::cout << "Looks like you weren't bluffing!" << std::endl;
      std::cout << get_flag() << std::endl;
      return 0;
    }
    else
    {
      std::cout << "Oh no, were you bluffing too?" << std::endl;
      std::cout << ours << std::endl;
    }
  }
}

const std::string get_flag() {
  char* env_value = std::getenv("FLAG");
  if (env_value) {
    return std::string(env_value);
  }

  const std::string flag_filename = maybe_get_env("FLAG_FILE", "/flag");
  std::ifstream flag_file(flag_filename);
  if (!flag_file.is_open()) {
    return "no flag configured! contact orga";
  }

  std::string flag;
  std::getline(flag_file, flag);
  flag_file.close();
  if (flag.empty()) {
    return "no flag configured! contact orga";
  }
  return flag;
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
