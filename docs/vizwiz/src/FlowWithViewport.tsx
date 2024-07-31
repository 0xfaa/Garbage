import { useState, useCallback, useEffect, useMemo, useRef } from "react";
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

const NODE_WIDTH = 500;
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
  const [selectedNodeIndex, setSelectedNodeIndex] = useState(0);
  const keyPressIntervalRef = useRef<number | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

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
        // Focus on the new node when it's added
        setSelectedNodeIndex(newStates.length - 1);
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
        data: {
          state,
          label: `Instruction ${index}`,
          selected: index === selectedNodeIndex,
        } as NodeData,
        className:
          index === selectedNodeIndex
            ? "shadow-blue-500/50 shadow-lg transition-shadow duration-300"
            : "transition-shadow duration-300",
      })),
    [states, selectedNodeIndex]
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

  const moveCamera = useCallback(
    (index: number) => {
      const node = nodes[index];
      if (node) {
        const x = node.position.x + NODE_WIDTH / 2;
        const y = node.position.y + NODE_HEIGHT / 2;
        const zoom = getZoom();
        setCenter(x, y, { duration: 800, zoom });
      }
    },
    [nodes, getZoom, setCenter]
  );

  const handleKeyPress = useCallback(
    (e: KeyboardEvent) => {
      // Only handle key events when the textarea is not focused
      if (document.activeElement !== textareaRef.current) {
        if (e.code === "Space") {
          e.preventDefault();
          moveCamera(selectedNodeIndex);
        } else if (e.code === "k") {
          e.preventDefault();
          setSelectedNodeIndex((prev) => Math.max(0, prev - 1));
        } else if (e.code === "j") {
          e.preventDefault();
          setSelectedNodeIndex((prev) => Math.min(nodes.length - 1, prev + 1));
        }
      }
    },
    [selectedNodeIndex, nodes.length, moveCamera]
  );

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      // Only handle key events when the textarea is not focused
      if (document.activeElement !== textareaRef.current) {
        if (e.code === "ArrowUp" || e.code === "ArrowDown") {
          e.preventDefault();
          setSelectedNodeIndex((prev) => {
            if (e.code === "ArrowUp") {
              const newIndex = Math.max(0, prev - 1);
              moveCamera(newIndex);
              return newIndex;
            } else {
              const newIndex = Math.min(nodes.length - 1, prev + 1);
              moveCamera(newIndex);
              return newIndex;
            }
          });
        }
      }
    },
    [nodes.length, moveCamera]
  );

  const handleKeyUp = useCallback(() => {
    if (keyPressIntervalRef.current !== null) {
      window.clearInterval(keyPressIntervalRef.current);
      keyPressIntervalRef.current = null;
    }
  }, []);

  useEffect(() => {
    window.addEventListener("keypress", handleKeyPress);
    window.addEventListener("keydown", handleKeyDown);
    window.addEventListener("keyup", handleKeyUp);
    return () => {
      window.removeEventListener("keypress", handleKeyPress);
      window.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("keyup", handleKeyUp);
    };
  }, [handleKeyPress, handleKeyDown, handleKeyUp]);

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
        fitView({ duration: 0, padding: 0.1 });

        if (currentStates.length < prevStates.length) {
          setSelectedNodeIndex(
            Math.min(selectedNodeIndex, currentStates.length - 1)
          );
        } else if (currentStates.length > prevStates.length) {
          // Focus on the new node when it's added
          setSelectedNodeIndex(currentStates.length - 1);
        }

        moveCamera(selectedNodeIndex);
      }

      prevStatesRef.current = states;
    }
  }, [nodes, states, fitView, moveCamera, selectedNodeIndex]);

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
          ref={textareaRef}
          className="text-sm w-full h-full p-2 border-none font-mono outline-none rounded text-black"
          value={assemblyCode}
          onChange={(e) => setAssemblyCode(e.target.value)}
          placeholder="Enter instructions..."
        />
      </div>
    </div>
  );
};
