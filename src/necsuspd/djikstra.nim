import std/[hashes, sets, deques, strformat, tables, algorithm, sequtils, heapqueue]

type
  DjikstraRouteNode* =
    concept n
        ## An individual node in the input map
        (n == n) is bool
        hash(n) is Hash

  DjikstraNode*[T, N] = tuple[stepCost, totalCost: T, next: N]
    ## A node in the resulting djikstra graph

  DjikstraQueueNode*[T, N] = object
    ## A unit of work while calculating the djikstra graph
    node: N
    cost: T

  DjikstraGraph*[T, N] = object
    ## Holds a precalculated graph of distances to a target node
    nodes: Table[N, DjikstraNode[T, N]]

  DjikstraInput*[T, N] =
    concept i
        ## Holds the input data for the Djikstra algorithm
        for target in i.targets:
          type(target) is N

        for neighbor in i.neighbors(N):
          type(neighbor) is N

        i.cost(N, N) is T

proc cost*[T, N](graph: DjikstraGraph[T, N], node: N): T =
  graph.nodes.getOrDefault(node).totalCost

proc contains*[T, N](graph: DjikstraGraph[T, N], node: N): bool =
  node in graph.nodes

proc `[]`*[T, N](graph: DjikstraGraph[T, N], node: N): DjikstraNode[T, N] =
  ## Returns the node in the graph for the input node
  graph.nodes[node]

proc `<`*[T, N](a, b: DjikstraQueueNode[T, N]): bool =
  ## Define custom comparison proc for ordering the heap
  a.cost < b.cost

proc `$`*[T, N](graph: DjikstraGraph[T, N]): string =
  result = "{"
  var first = true
  for key in graph.nodes.keys.toSeq().sorted():
    if first:
      first = false
      result &= '\n'
    let (totalCost, next) = graph.nodes[key]
    result &= fmt"  {key} -> {next} @{totalCost},{'\n'}"
  result &= "}"

proc calculateDjikstra*[T, N: DjikstraRouteNode](
    map: DjikstraInput[T, N]
): DjikstraGraph[T, N] =
  ## Generates a Djikstra graph from the given input map
  result = DjikstraGraph[T, N](nodes: initTable[N, DjikstraNode[T, N]]())

  var processed = initHashSet[N]()
  var queue = initHeapQueue[DjikstraQueueNode[T, N]]()

  # Initialize with targets
  for target in map.targets:
    let cost = map.cost(target, target)
    result.nodes[target] = (cost, cost, target)
    queue.push(DjikstraQueueNode[T, N](cost: cost, node: target))

  while queue.len > 0:
    let work = queue.pop()

    if work.node notin processed:
      processed.incl(work.node)

      # Process all neighbors
      for neighbor in map.neighbors(work.node):
        let stepCost = map.cost(neighbor, work.node)
        let neighborCost = work.cost + stepCost

        if neighbor notin result.nodes or neighborCost < result.nodes[neighbor].totalCost:
          result.nodes[neighbor] = (stepCost, neighborCost, work.node)
          queue.push(DjikstraQueueNode[T, N](cost: neighborCost, node: neighbor))
