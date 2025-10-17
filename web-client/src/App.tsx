import React, { useState } from 'react';
import { createConnectTransport } from '@connectrpc/connect-web';
import { createPromiseClient } from '@connectrpc/connect';
import { ExampleServiceService } from './gen/example-service_connect';
import { GetStatusRequest, StreamDataRequest } from './gen/example-service_pb';

// Create transport to connect to the gRPC-Web proxy
// Use HTTPS in production, HTTP in development (webpack proxy)
const isDevelopment = process.env.NODE_ENV === 'development';
const transport = createConnectTransport({
  baseUrl: isDevelopment ? '/api' : 'https://localhost:8443/api', // This will be proxied by nginx to the gRPC service
});

// Create a client
const client = createPromiseClient(ExampleServiceService, transport);

function App() {
  const [serviceId, setServiceId] = useState('example-service-1');
  const [statusResult, setStatusResult] = useState<string>('');
  const [statusError, setStatusError] = useState<string>('');
  const [statusLoading, setStatusLoading] = useState(false);

  const [streamFilter, setStreamFilter] = useState('test');
  const [streamLimit, setStreamLimit] = useState(5);
  const [streamData, setStreamData] = useState<Array<{ data: string; timestamp: string }>>([]);
  const [streamError, setStreamError] = useState<string>('');
  const [streamLoading, setStreamLoading] = useState(false);

  const handleGetStatus = async () => {
    setStatusLoading(true);
    setStatusError('');
    setStatusResult('');

    try {
      const request = new GetStatusRequest({
        serviceId: serviceId,
      });

      const response = await client.getStatus(request);
      setStatusResult(JSON.stringify({
        status: response.status,
        message: response.message,
      }, null, 2));
    } catch (error) {
      setStatusError(`Error: ${error}`);
    } finally {
      setStatusLoading(false);
    }
  };

  const handleStreamData = async () => {
    setStreamLoading(true);
    setStreamError('');
    setStreamData([]);

    try {
      const request = new StreamDataRequest({
        filter: streamFilter,
        limit: streamLimit,
      });

      // Note: For streaming, we'd need to implement server-side streaming support
      // This is a simplified example that would need additional setup
      const stream = client.streamData(request);
      
      const streamResults: Array<{ data: string; timestamp: string }> = [];
      
      for await (const response of stream) {
        const item = {
          data: response.data,
          timestamp: new Date(Number(response.timestamp)).toLocaleString(),
        };
        streamResults.push(item);
        setStreamData([...streamResults]);
      }
    } catch (error) {
      setStreamError(`Error: ${error}`);
    } finally {
      setStreamLoading(false);
    }
  };

  return (
    <div className="container">
      <div className="header">
        <h1>Example Service Client</h1>
        <p>gRPC-Web client for the GoMicroserviceFramework example service</p>
      </div>

      <div className="section">
        <h2>Get Status (Unary RPC)</h2>
        <div className="form-group">
          <label htmlFor="serviceId">Service ID:</label>
          <input
            id="serviceId"
            type="text"
            value={serviceId}
            onChange={(e) => setServiceId(e.target.value)}
            placeholder="Enter service ID"
          />
        </div>
        <button 
          className="btn" 
          onClick={handleGetStatus} 
          disabled={statusLoading}
        >
          {statusLoading ? 'Loading...' : 'Get Status'}
        </button>
        
        {statusResult && (
          <div className="result">
            <strong>Result:</strong>
            {statusResult}
          </div>
        )}
        
        {statusError && (
          <div className="error">
            {statusError}
          </div>
        )}
      </div>

      <div className="section">
        <h2>Stream Data (Server Streaming RPC)</h2>
        <div className="form-group">
          <label htmlFor="streamFilter">Filter:</label>
          <input
            id="streamFilter"
            type="text"
            value={streamFilter}
            onChange={(e) => setStreamFilter(e.target.value)}
            placeholder="Enter filter"
          />
        </div>
        <div className="form-group">
          <label htmlFor="streamLimit">Limit:</label>
          <input
            id="streamLimit"
            type="number"
            value={streamLimit}
            onChange={(e) => setStreamLimit(parseInt(e.target.value, 10) || 1)}
            min="1"
            max="100"
          />
        </div>
        <button 
          className="btn" 
          onClick={handleStreamData} 
          disabled={streamLoading}
        >
          {streamLoading ? 'Streaming...' : 'Start Stream'}
        </button>
        
        {streamData.length > 0 && (
          <div className="stream-data">
            <strong>Stream Data:</strong>
            {streamData.map((item, index) => (
              <div key={index} className="stream-item">
                <strong>{item.timestamp}:</strong> {item.data}
              </div>
            ))}
          </div>
        )}
        
        {streamError && (
          <div className="error">
            {streamError}
          </div>
        )}
      </div>
    </div>
  );
}

export default App;