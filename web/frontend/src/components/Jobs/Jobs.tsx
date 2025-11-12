/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { useParams } from "react-router";
import { useEffect, useRef, useState } from "react";
import Header from "./Header";
import Footer from "../Common/Footer";
import SectionHeader from "../Common/SectionHeader/SectionHeader";
import styles from "./Jobs.module.css";
import formStyles from "../Common/Forms/Form.module.css";

interface JobData {
  log: string;
  solution: any;
  position: number;
}

const Jobs = () => {
  const { jobId } = useParams();
  const [jobData, setJobData] = useState<JobData | null>(null);
  const logRef = useRef<HTMLDivElement>(null);
  const previousLogRef = useRef<string>("");
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const fetchJobData = async () => {
      const backendUrl = process.env.REACT_APP_BACKEND_URL;
      const response = await fetch(`${backendUrl}/jobs/${jobId}/view`);
      if (!response.ok) {
        console.error(response);
        return;
      }
      const data = await response.json();

      if (data.solution) {
        // Stop polling if solution exists
        if (intervalRef.current) {
          clearInterval(intervalRef.current);
          intervalRef.current = null;
        }

        // Parse solution
        data.solution = JSON.parse(data.solution);
      }

      // Update data
      setJobData(data);
      console.log(data);
    };

    // Fetch immediately
    fetchJobData();

    // Set up polling every second
    intervalRef.current = setInterval(fetchJobData, 1000);

    // Cleanup interval on unmount
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [jobId]);

  // Auto-scroll to the bottom when log content changes
  useEffect(() => {
    if (jobData?.log && jobData.log !== previousLogRef.current) {
      previousLogRef.current = jobData.log;
      if (logRef.current) {
        logRef.current.scrollTop = logRef.current.scrollHeight;
      }
    }
  }, [jobData?.log]);

  return (
    <div>
      <Header />
      <div className="content">
        <SectionHeader title="Optimization log"></SectionHeader>
        <div className={formStyles.FormWrapper}>
          <div className={styles.SolverLog} ref={logRef}>
            {jobData
              ? jobData.log || `Waiting for ${jobData.position} other optimization job(s) to finish...`
              : "Loading..."}
          </div>
        </div>
      </div>
      <Footer />
    </div>
  );
};

export default Jobs;
