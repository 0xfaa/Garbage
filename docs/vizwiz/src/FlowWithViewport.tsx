import {
  useState,
  useCallback,
  useEffect,
  useMemo,
  useRef,
} from "react";
import ReactFlow, {
  Background,
  Controls,
  Edge,
  Connection,
  addEdge,
  MarkerType,
  useReactFlow,
} from "react-flow-renderer";
import NodeContent from "./NodeContent";
import { NodeData } from "./types";
import { type State, parseAndExecute, Stack } from "./vizwiz";
import debounce from "lodash/debounce";
import { isEqual } from "lodash";

const NODE_HEIGHT = 410;
const VERTICAL_SPACING = 69;

export const FlowWithViewport = () => {
  const { fitView, setCenter, getZoom } = useReactFlow();

  const [stack] = useState(() => {
    const s = new Stack(16);
    s.registers["x29"] = BigInt("0x1111111111111111");
    s.registers["x30"] = BigInt("0x2222222222222222");
    return s;
  });

  const [assemblyCode, setAssemblyCode] = useState("");
  const [states, setStates] = useState<State[]>([stack.snapshot("init")]);
  const prevStatesRef = useRef<State[]>([]);

  const updateStates = useMemo(
    () =>
      debounce((code: string) => {
        const lines = code.split("\n").filter((line) => line.trim());
        const newStates: State[] = [stack.snapshot("init")];

        const tempStack = new Stack(16);
        tempStack.registers["x29"] = BigInt("0x1111111111111111");
        tempStack.registers["x30"] = BigInt("0x2222222222222222");

        lines.forEach((line) => {
          const newState = parseAndExecute(tempStack, line.trim());
          stack.decrement_label_renders();
          newStates.push(newState);
        });

        setStates(newStates);
      }, 300),
    [stack]
  );

  useEffect(() => {
    updateStates(assemblyCode);
  }, [assemblyCode, updateStates]);

  const nodes = useMemo(
    () =>
      states.map((state, index) => ({
        id: `node-${index}`,
        type: "custom",
        position: {
          x: 0,
          y: index * (NODE_HEIGHT + VERTICAL_SPACING),
        },
        data: { state, label: `Instruction ${index}` } as NodeData,
      })),
    [states]
  );

  const edges = useMemo(
    () =>
      nodes.slice(0, -1).map((node, index) => ({
        id: `edge-${index}`,
        source: node.id,
        target: `node-${index + 1}`,
        type: "smoothstep",
        animated: true,
        markerEnd: {
          type: MarkerType.ArrowClosed,
        },
      })),
    [nodes]
  );

  const onConnect = useCallback(
    (params: Edge | Connection) => setStates((prev) => addEdge(params, prev)),
    []
  );

  useEffect(() => {
    if (nodes.length > 0) {
      const currentStates = states.map((state) => ({
        instruction: state.instruction,
        stack: state.stack,
        registers: state.registers,
      }));

      const prevStates = prevStatesRef.current.map((state) => ({
        instruction: state.instruction,
        stack: state.stack,
        registers: state.registers,
      }));

      if (!isEqual(currentStates, prevStates)) {
        // First, fit view to all nodes
        fitView({ duration: 0, padding: 0.1 });

        // Then, center on the last node
        const lastNode = nodes[nodes.length - 1];
        const x = lastNode.position.x + NODE_HEIGHT / 2;
        const y = lastNode.position.y + VERTICAL_SPACING / 2;

        // Use the current zoom level
        const zoom = getZoom();

        // Animate to the new node
        setCenter(x, y, { duration: 800, zoom });
      }

      prevStatesRef.current = states;
    }
  }, [nodes, states, fitView, setCenter, getZoom]);

  return (
    <div className="flex h-screen">
      {/* title */}
      <div className="absolute top-5 left-5 opacity-35 z-10">
        <span className="text-md">Viz Wiz</span>
        <br />
        <span className="text-xs">
          Apple M1 arm64 assembly visualizer
          <br />
          <a
            href="https://x.com/0x466161"
            className="underline"
            target="_blank"
          >
            Made by @faa
          </a>
        </span>
      </div>

      <div className="flex-1 h-full">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={() => {}}
          onEdgesChange={() => {}}
          onConnect={onConnect}
          nodeTypes={{ custom: NodeContent }}
          fitView
        >
          <Background />
          <Controls />
        </ReactFlow>
      </div>
      <div className="bg-zinc-200 overflow-y-auto w-72 flex flex-col items-center p-2">
        <h2 className="text-xl font-bold mb-2 px-2 text-zinc-800">
          AArch64 code
        </h2>
        <textarea
          className="text-sm w-full h-full p-2 border-none font-mono outline-none rounded text-black"
          value={assemblyCode}
          onChange={(e) => setAssemblyCode(e.target.value)}
          placeholder="Enter instructions..."
        />
      </div>
    </div>
  );
};
