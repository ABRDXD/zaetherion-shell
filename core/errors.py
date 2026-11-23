class OpError(Exception):
    """A request failure reported to the client as {code, message}."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def bad_args(message: str) -> OpError:
    return OpError("bad-args", message)
