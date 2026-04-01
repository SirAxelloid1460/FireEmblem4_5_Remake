class Node():
    __slots__ = ['reachable', 'cost', 'x', 'y', 'parent', 'g', 'h', 'f', 'true_f']

    def __init__(self, x: int, y: int, reachable: bool, cost: float):
        """
        Initialize new cell
        reachable - is cell reachable? is not a wall?
        cost - how many movement points to reach
        """
        self.reachable = reachable
        self.cost = cost
        self.x = x
        self.y = y
        self.reset()

    def reset(self):
        self.parent = None
        self.g = 0
        self.h = 0
        self.f = 0
        self.true_f = 0

    def __gt__(self, n):
        return self.cost > n

    def __lt__(self, n):
        return self.cost < n

    def __repr__(self):
        return "Node(%d, %d): cost=%d, g=%d, h=%d, f=%f, %s" % (self.x, self.y, self.cost, self.g, self.h, self.f, self.reachable)
