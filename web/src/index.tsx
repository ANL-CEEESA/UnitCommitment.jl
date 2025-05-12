import React from 'react';
import ReactDOM from 'react-dom/client';
import reportWebVitals from './reportWebVitals';
import CaseBuilder from "./components/CaseBuilder/CaseBuilder";

const root = ReactDOM.createRoot(
    document.getElementById('root') as HTMLElement
);

root.render(
    <React.StrictMode>
        <CaseBuilder/>
    </React.StrictMode>
);

reportWebVitals();
