import { useState, useCallback, useEffect, useMemo, useRef } from "react";
import ReactFlow, {
  Background,
  Controls,
  Edge,
  Connection,
  addEdge,
  MarkerType,
  useReactFlow,
  EdgeMarker,
  NodeTypes,
} from "react-flow-renderer";
import NodeContent from "./NodeContent";
import { NodeData } from "./types";
import { type State, parseAndExecute, Stack } from "./vizwiz";
import debounce from "lodash/debounce";
import { isEqual } from "lodash";

const NODE_WIDTH = 800;
const NODE_HEIGHT = 1010;
const SPACING = 69;
const STACK_SIZE = 255;

const nodeTypes: NodeTypes = { custom: NodeContent };

export const FlowWithViewport = () => {
  const { fitView, setCenter, getZoom } = useReactFlow();

  const [stack] = useState(() => {
    const s = new Stack(STACK_SIZE);
    s.registers["x29"] = BigInt("0x1111111111111111");
    s.registers["x30"] = BigInt("0x2222222222222222");
    return s;
  });

  const [assemblyCode, setAssemblyCode] = useState("");
  const [states, setStates] = useState<State[]>([
    stack.snapshot("init"),
    stack.snapshot("init"),
  ]);
  const prevStatesRef = useRef<State[]>([]);
  const [currentPairIndex, setCurrentPairIndex] = useState(0);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [autoFocus, setAutoFocus] = useState(true);

  const nodes = useMemo(
    () =>
      states.map((state, index) => ({
        id: `node-${index}`,
        type: "custom",
        position: {
          x: index * (NODE_WIDTH + SPACING),
          y: 0,
        },
        data: {
          state,
          label: `Instruction ${index}`,
          selected:
            index === currentPairIndex || index === currentPairIndex + 1,
        } as NodeData,
        className: `transition-shadow duration-300 ${
          index === currentPairIndex || index === currentPairIndex + 1
            ? "shadow-blue-500/50 shadow-lg"
            : ""
        }`,
      })),
    [states, currentPairIndex]
  );

  const visibleNodes = useMemo(
    () => nodes.slice(currentPairIndex, currentPairIndex + 2),
    [nodes, currentPairIndex]
  );

  const moveCamera = useCallback(() => {
    if (visibleNodes.length > 0) {
      const firstNodeX = visibleNodes[0].position.x;
      const lastNodeX = visibleNodes[visibleNodes.length - 1].position.x;
      const centerX = (firstNodeX + lastNodeX + NODE_WIDTH) / 2;
      const centerY = NODE_HEIGHT / 2;
      const zoom = getZoom();
      setCenter(centerX, centerY, { duration: 800, zoom });
    }
  }, [visibleNodes, getZoom, setCenter]);

  const updateStates = useMemo(
    () =>
      debounce((code: string) => {
        const lines = code.split("\n").filter((line) => line.trim());
        const newStates: State[] = [stack.snapshot("init")];

        const tempStack = new Stack(STACK_SIZE);
        tempStack.registers["x29"] = BigInt("0x1111111111111111");
        tempStack.registers["x30"] = BigInt("0x2222222222222222");

        lines.forEach((line) => {
          const newState = parseAndExecute(tempStack, line.trim());
          stack.decrement_label_renders();
          newStates.push(newState);
        });

        if (newStates.length === 1) {
          newStates.push(newStates[0]);
        }

        setStates(newStates);
        if (autoFocus) {
          setCurrentPairIndex(Math.max(0, newStates.length - 2));
        }
      }, 300),
    [stack, autoFocus]
  );

  useEffect(() => {
    updateStates(assemblyCode);
  }, [assemblyCode, updateStates]);

  useEffect(() => {
    if (autoFocus && states.length > prevStatesRef.current.length) {
      setCurrentPairIndex(Math.max(0, states.length - 2));
      moveCamera();
    }
    prevStatesRef.current = states;
  }, [states, autoFocus, moveCamera]);

  const edges = useMemo(() => {
    if (visibleNodes.length < 2) return [];
    return [
      {
        id: "pair-edge",
        source: visibleNodes[0].id,
        target: visibleNodes[1].id,
        type: "straight",
        animated: true,
        style: { stroke: "#ffffff", strokeWidth: 2 },
        sourceHandle: "right",
        targetHandle: "left",
        markerEnd: {
          type: MarkerType.ArrowClosed,
          color: "#ffffff",
        } as EdgeMarker,
      },
    ];
  }, [visibleNodes]);

  const onConnect = useCallback(
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    (params: Edge | Connection) => setStates((prev) => addEdge(params, prev)),
    []
  );

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (document.activeElement !== textareaRef.current) {
        if (e.code === "ArrowLeft" || e.code === "ArrowRight") {
          e.preventDefault();
          setCurrentPairIndex((prev) => {
            const newIndex =
              e.code === "ArrowLeft"
                ? Math.max(0, prev - 1)
                : Math.min(states.length - 2, prev + 1);
            return newIndex;
          });
        } else if (e.code === "Space") {
          e.preventDefault();
          moveCamera();
        } else if (e.code === "KeyF") {
          e.preventDefault();
          setAutoFocus((prev) => !prev);
        }
      }
    },
    [states.length, moveCamera]
  );

  useEffect(() => {
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [handleKeyDown]);

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
        if (currentStates.length !== prevStates.length) {
          fitView({ duration: 800, padding: 0.2 });
        }
        moveCamera();
      }

      prevStatesRef.current = states;
    }
  }, [nodes, states, moveCamera, fitView]);

  useEffect(() => {
    moveCamera();
  }, [currentPairIndex, moveCamera]);

  return (
    <div className="flex h-screen">
      <div className="absolute top-5 left-5 opacity-35 z-10 text-white">
        <span className="text-md">Viz Wiz</span>
        <br />
        <span className="text-xs">
          Apple M1 arm64 assembly visualizer
          <br />
          <a
            href="https://x.com/0x466161"
            className="underline"
            target="_blank"
            rel="noopener noreferrer"
          >
            Made by @faa
          </a>
          <br />
        </span>
      </div>

      <div className="absolute bottom-5 left-14 text-white z-10 text-xs opacity-35">
        <span className="opacity-50">
          Use arrow left/right keys to navigate.
          <br />
          Press Space to center.
          <br />
          Press F to toggle auto-focus ({autoFocus ? "ON" : "OFF"}).
        </span>
      </div>

      <div className="flex-1 h-full">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={() => {}}
          onEdgesChange={() => {}}
          onConnect={onConnect}
          nodeTypes={nodeTypes}
          fitView
          fitViewOptions={{ padding: 0.2 }}
          className="bg-black text-white"
        >
          <Background />
          <Controls />
        </ReactFlow>
      </div>
      <div className="bg-zinc-200 overflow-y-auto w-72 flex flex-col items-center p-2 bg-zinc-800">
        <h2 className="text-xl font-bold mb-2 px-2 text-white">AArch64 code</h2>
        <textarea
          ref={textareaRef}
          className="text-sm w-full h-full p-2 border-none font-mono outline-none rounded text-black bg-zinc-900 text-white placeholder-white"
          value={assemblyCode}
          onChange={(e) => setAssemblyCode(e.target.value)}
          placeholder="Enter instructions..."
        />
      </div>
    </div>
  );
};
