#include "chall_rng.hpp"

#include <random>

std::random_device rd;

ChallRng::ChallRng(result_type team_seed) {
  ts = team_seed;
  random_device_seed = rd();
}

ChallRng::ChallRng(result_type candidate_team_seed, result_type given_seed) {
  ts = candidate_team_seed;
  random_device_seed = given_seed;
}

ChallRng::result_type ChallRng::next() {
  if (!did_initialize_mt) {
    std::seed_seq seed({ts, random_device_seed});
    mt.seed(seed);
    did_initialize_mt = true;
  }
  return mt();
}
