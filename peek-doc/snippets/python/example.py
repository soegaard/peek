# Python preview example.
def answer(name: str) -> str:
    label = name.title()
    return f"Hello, {label}"

if __name__ == "__main__":
    print(answer("peek"))
