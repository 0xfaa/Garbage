import { ReactFlowProvider } from "react-flow-renderer";
import { FlowWithViewport } from "./FlowWithViewport";


const App: React.FC = () => {
  return (
    <ReactFlowProvider>
      <FlowWithViewport />
    </ReactFlowProvider>
  );
};

export default App;