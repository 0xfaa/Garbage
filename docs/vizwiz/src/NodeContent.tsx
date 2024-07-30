import React from "react";
import { NodeData } from "./types";
import { Handle, Position } from "react-flow-renderer";

interface NodeContentProps {
  data: NodeData;
}

const NodeContent: React.FC<NodeContentProps> = ({ data }) => {
  const { state, label } = data;

  const byteToHex = (byte: bigint): string => {
    return byte.toString(16).padStart(2, "0");
  };

  const getStackBytes = (): bigint[] => {
    const bytes: bigint[] = [];
    state.stack.forEach((value) => {
      for (let i = 7; i >= 0; i--) {
        bytes.push((BigInt(value) >> (BigInt(i) * BigInt(8))) & BigInt(0xff));
      }
    });
    return bytes;
  };

  const spIndex = BigInt(state.registers.sp);
  const fpIndex = BigInt(state.registers.fp);

  const stackBytes = getStackBytes();
  const totalRows = stackBytes.length / 8;

  console.log(state.labels)

  return (
    <div className="p-4 border border-gray-300 rounded-md bg-white font-mono w-[500px] h-[410px] overflow-auto hover:cursor-pointer">
      <Handle type="target" position={Position.Left} />
      <h3 className="text-md font-bold mb-2">
        {label}: {state.instruction}
      </h3>
      <span className="text-gray-900 font-bold text-md">Stack</span>
      <div className="text-sm w-fit flex mt-2">
        <div className="flex-grow">
          {Array.from({ length: totalRows }, (_, index) => {
            const rowIndex = totalRows - 1 - index;
            const rowAddress = BigInt(rowIndex * 8);
            const labels = state.labels[rowIndex];
            return (
              <div key={rowIndex} className="flex items-center mt-1">
                <span className="w-8 text-xs">
                  [{rowIndex.toString().padStart(2, "0")}]
                </span>
                <div className={`flex flex-wrap justify-start`}>
                  {stackBytes.slice(rowIndex * 8, (rowIndex + 1) * 8).map((byte, byteIndex) => {
                    const byteAddress = rowAddress + BigInt(7 - byteIndex);
                    return (
                      <span
                        key={byteIndex}
                        className={`mr-1 px-1 text-xs ${
                          byte !== BigInt(0) && 'text-red-500'
                        } ${
                          byteAddress === spIndex
                            ? "bg-green-400"
                            : byteAddress === fpIndex
                            ? "bg-blue-400"
                            : "bg-gray-100"
                        }`}
                      >
                        {byteToHex(byte)}
                      </span>
                    );
                  })}
                </div>
                <div className="flex items-center ml-2">
                  {rowAddress <= spIndex && spIndex < rowAddress + BigInt(8) && (
                    <span className="text-green-600 text-xs mr-2">SP {state.modified_registers.includes('sp') && <span className="text-red-500">*</span>}</span>
                  )}
                  {rowAddress <= fpIndex && fpIndex < rowAddress + BigInt(8) && (
                    <span className="text-blue-600 text-xs mr-2">FP</span>
                  )}
                  {labels && labels.length > 0 && (
                    <span className="text-purple-600 text-xs">
                      {labels.map((label: [string, number]) => {
                        return label[0]
                      }).join(', ')}
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
      <Handle type="source" position={Position.Right} />
    </div>
  );
};

export default NodeContent;