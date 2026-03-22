from __future__ import annotations
import math
from typing import Dict, Generic, Iterable, List, Set, Tuple, TypeVar

V = TypeVar("V")
D = TypeVar("D")
E = TypeVar("E")

class LTEdge(Generic[V, E]):
    """An edge implementation.
    """
    def __init__(self, endpoints: Tuple[V, V], data: E = None, weight: float = 1):
        self.endpoints = endpoints
        self.data = data
        self.weight = max(weight, 0)

class LTVertex(Generic[V, D, E]):
    """A vertex implementation.
    """
    def __init__(self, value: V, data: D = None):
        self.value = value
        self.data = data
        self.edges: Dict[V, LTEdge] = {}

    def __getitem__(self, value: V) -> LTEdge[V, E]:
        return self.edges[value]

    def __setitem__(self, index: V, edge: LTEdge[V, E]):
        self.edges[index] = edge

    def __repr__(self):
        return repr(self.edges.keys())

class LTGraph(Generic[V, D, E]):
    """An undirected graph implementation for the LT engine, since installing
    external dependencies is extremely cringe.

    Does not support negative edge weights.
    """

    def __init__(self, vertices: Iterable[V]=None, edges: Iterable[Tuple[V, V]] = None):
        self.vertices: Dict[V, LTVertex] = {}
        self.adj: Dict[V, Set[V]] = {}
        self._path_dict: Dict[V, Dict[V, List[Tuple[V, V]]]] = {}
        if vertices:
            for vertex in vertices:
                self.add_vertex(vertex)
        if edges:
            for edge in edges:
                v1, v2 = edge
                self.add_edge(v1, v2)

    def add_vertex(self, vertex_val: V, vertex_data: D = None):
        self[vertex_val] = LTVertex(vertex_val, vertex_data)
        self.adj[vertex_val] = set()
        self.clear_cache()

    def add_edge(self, v1: V, v2: V, data: E = None, weight: float = 1):
        """Add edge to graph between two vertices (they do not necessarily have to be predefined)

        Args:
            v1 (V): One endpoint of edge.
            v2 (V): Other endpoint.
            data (E, optional): Data associated with edge. Defaults to None.
            weight (float, optional): Edge weight. Does not support negative weights. Defaults to 1.
        """
        # sanity check
        if v1 == v2:
            return

        if v1 not in self.vertices:
            self[v1] = LTVertex(v1)
            self.adj[v1] = set()
        if v2 not in self.vertices:
            self[v2] = LTVertex(v2)
            self.adj[v2] = set()

        self[v1][v2] = LTEdge((v1, v2), data, weight)
        self[v2][v1] = LTEdge((v2, v1), data, weight)

        self.adj[v1].add(v2)
        self.adj[v2].add(v1)
        self.clear_cache()

    def has_path(self, v1: V, v2: V) -> bool:
        """Determines whether or not a path exists between the two nodes.
        NOTE: I don't give a rat's ass about performance, but
        if you, reader, do, turn this into bfs or use a cache or something.
        """
        if self.shortest_path(v1, v2):
            return True
        return False

    def shortest_path(self, v1: V, v2: V) -> List[V]:
        """Fetches the shortest path between two vertices.

        Args:
            v1, v2 (V): vertices to fetch path for

        Returns:
            List[Tuple[V, V]]: Shortest path, represented in vertex connections
        """
        # some sanity checks
        if v1 not in self.vertices.keys() or v2 not in self.vertices.keys():
            return None

        if v1 == v2:
            return []

        # if shortest path cached
        if v1 in self._path_dict and v2 in self._path_dict[v1]:
            return self._path_dict[v1][v2]

        # else, initialize shortest paths dict if not initialized
        if v1 not in self._path_dict:
            self._path_dict[v1] = {}
        if v2 not in self._path_dict:
            self._path_dict[v2] = {}

        # and run djikstra from v1 to v2
        visited: Dict[V, float] = {}
        prev_step: Dict[V, V] = {}
        dist_from_v1 = {vert_id: math.inf for vert_id in self.vertices.keys()}
        dist_from_v1[v1] = 0
        while len(dist_from_v1.keys()) != 0:
            min_dist = min(dist_from_v1.values())
            min_vert = [vert for vert in dist_from_v1 if dist_from_v1[vert] == min_dist][0]
            visited[min_vert] = min_dist
            next_verts = self.adj[min_vert]
            for neighbor in next_verts:
                if neighbor not in visited.keys():
                    neighbor_dist = min_dist + self[min_vert][neighbor].weight
                    if neighbor_dist < dist_from_v1[neighbor]:
                        prev_step[neighbor] = min_vert
                        dist_from_v1[neighbor] = neighbor_dist
            dist_from_v1.pop(min_vert)

        # does a path exist
        if v2 not in visited.keys():
            self._path_dict[v1][v2] = None
            self._path_dict[v2][v1] = None
            return None
        # reconstruct it
        path = []
        reverse_path = []
        curr_vert = v2
        while curr_vert != v1:
            best_neighbor = prev_step[curr_vert]
            reverse_path.append(curr_vert)
            path.insert(0, curr_vert)
            curr_vert = best_neighbor
        reverse_path.append(curr_vert)
        path.insert(0, curr_vert)

        self._path_dict[v1][v2] = path
        self._path_dict[v2][v1] = reverse_path
        return path

    def clear_cache(self):
        # usually we want to regenerate all paths after adding nodes
        self._path_dict.clear()

    def __contains__(self, value: V) -> bool:
        if value in self.vertices:
            return True
        else:
            return False

    def __getitem__(self, value: V) -> LTVertex[V, D, E]:
        return self.vertices[value]

    def __setitem__(self, index: V, vertex: LTVertex[V, D, E]):
        self.vertices[index] = vertex

    def __repr__(self):
        return repr(self.vertices)
