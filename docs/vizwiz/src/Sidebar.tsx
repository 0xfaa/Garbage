import React from 'react';
import { State } from './types';

interface SidebarProps {
  selectedNode: State | null;
}

const Sidebar: React.FC<SidebarProps> = ({ selectedNode }) => {
  if (!selectedNode) {
    return <div className="w-80 p-5 bg-gray-100 font-medium overflow-y-auto">Select a node...</div>;
  }

  return (
    <div className="w-80 p-5 bg-gray-100 overflow-y-auto">
      <h2 className="text-xl font-bold mb-4">Registers</h2>
      {Object.entries(selectedNode.registers).map(([reg, value]) => (
        <div key={reg} className="mb-2">
          <strong>{reg}:</strong> {BigInt(value).toString(16).padStart(16, '0')}
          {selectedNode.register_labels[reg].length > 0 && (
            <span className="ml-2">&lt; {selectedNode.register_labels[reg].map(l => l[0]).join(', ')}</span>
          )}
        </div>
      ))}
    </div>
  );
};

export default Sidebar;