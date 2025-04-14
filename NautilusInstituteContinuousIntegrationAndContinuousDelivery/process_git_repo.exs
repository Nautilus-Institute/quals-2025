#!/usr/bin/env elixir

# Script to process a git repository and execute an actor plan
# Usage: elixir process_git_repo.exs [bundle_path] [job_definitions_dir]

# Alias the main module for convenience
alias NautilusInstituteContinuousIntegrationAndContinuousDelivery, as: NICICD

defmodule ProcessGitRepo do
  def main do
    # Parse command line arguments
    {bundle_path, job_defs_dir} = parse_args()
    
    IO.puts("=== Nautilus Institute CI/CD Git Repository Processor ===")
    IO.puts("Git Bundle: #{bundle_path}")
    IO.puts("Job Definitions Directory: #{job_defs_dir}")
    
    # Start the registry and runner
    {:ok, _registry_pid} = NICICD.JobRegistry.start_link()
    {:ok, _runner_pid} = NICICD.JobRunner.start_link()
    
    # Load job definitions
    load_job_definitions(job_defs_dir)
    
    # Process the git repository and execute the actor plan
    case NICICD.process_git_repo_and_actor_plan(bundle_path) do
      {:ok, results} ->
        #IO.puts("\nExecution started successfully.")
        
        # Extract PIDs from results
        pids = for {job_name, result} <- results do
          pid = case result do
            pid when is_pid(pid) -> pid
            {:ok, pid} when is_pid(pid) -> pid
            _ -> nil
          end
          {job_name, pid}
        end
        
        # Filter out non-PID results
        job_pids = Enum.filter(pids, fn {_, pid} -> is_pid(pid) end)
        
        if job_pids != [] do
          IO.puts("Waiting for jobs to complete...")
          
          # Sleep in a loop checking job completion
          Enum.each(job_pids, fn {job_name, pid} ->
            wait_for_job(job_name, pid)
          end)
        end
        
        IO.puts("\nAll jobs completed.")
        IO.puts("Results:")
        Enum.each(results, fn {job_name, result} ->
          IO.puts("  - #{job_name}: #{inspect(result)}")
        end)
        
        # Sleep for 30 seconds to ensure all job output is captured
        IO.puts("Waiting 30 seconds before exit...")
        :timer.sleep(30000)
        
        System.stop(0)
        
      {:error, reason} ->
        IO.puts("\nExecution failed: #{inspect(reason)}")
        System.stop(1)
    end
  end
  
  defp parse_args do
    args = System.argv()
    
    bundle_path = case Enum.at(args, 0) do
      nil -> "my-pull-request.bundle"
      path -> path
    end
    
    job_defs_dir = case Enum.at(args, 2) do
      nil -> "common_jobs"
      dir -> dir
    end
    
    {bundle_path, job_defs_dir}
  end
  
  defp load_job_definitions(dir) do
    IO.puts("\nLoading job definitions from #{dir}...")
    
    job_files = Path.join(dir, "*.xml") |> Path.wildcard()
    
    loaded_count = Enum.reduce(job_files, 0, fn file, count ->
      case NICICD.JobLoader.register_jobs(file) do
        {:ok, file_count} -> count + file_count
        {:error, _} -> count
      end
    end)
    
    IO.puts("Loaded #{loaded_count} job definitions.")
    
    # Display available jobs
    job_names = NICICD.JobRegistry.list_jobs()
    
    if job_names != [] do
      IO.puts("\nAvailable jobs:")
      Enum.each(job_names, &IO.puts("  - #{&1}"))
    else
      IO.puts("\nNo jobs loaded. Please check job definition files.")
      System.stop(1)
    end
  end
  
  # Wait for a specific job to complete
  defp wait_for_job(job_name, pid) do
    if Process.alive?(pid) do
      IO.puts("Waiting for job #{job_name} (PID: #{inspect(pid)}) to complete...")
      Process.monitor(pid)
      wait_for_down(job_name, pid)
    else
      IO.puts("Job #{job_name} (PID: #{inspect(pid)}) already completed.")
    end
  end
  
  defp wait_for_down(job_name, pid) do
    receive do
      {:DOWN, _ref, :process, ^pid, _reason} -> 
        IO.puts("Job #{job_name} completed.")
    after
      1000 ->
        if Process.alive?(pid) do
          IO.puts("Job #{job_name} is still running...")
          wait_for_down(job_name, pid)
        else
          IO.puts("Job #{job_name} completed.")
        end
    end
  end
end

# Run the main function
ProcessGitRepo.main() 