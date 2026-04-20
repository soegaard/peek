// Tiny C++ sample
#include <vector>

class Greeter {
public:
  explicit Greeter(int value) : value_(value) {}
  int value() const { return value_; }

private:
  int value_;
};
