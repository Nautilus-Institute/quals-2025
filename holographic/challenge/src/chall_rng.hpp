#pragma once

#include <cstdint>
#include <random>

class ChallRng {
public:
    using result_type = std::mt19937::result_type;

    ChallRng(result_type team_seed);

    result_type next();

    result_type random_device_seed;

private:
  result_type ts;
  bool did_initialize_mt = false;
  std::mt19937 mt;
};