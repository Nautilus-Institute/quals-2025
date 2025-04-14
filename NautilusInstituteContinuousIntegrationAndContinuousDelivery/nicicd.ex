defmodule NautilusInstituteContinuousIntegrationAndContinuousDelivery do
  @moduledoc """
  Core module for the Nautilus Institute's CI/CD system.
  """

  @doc """
  Process a git repository and execute the actor plan found within it.
  
  Takes:
  - bundle_path: Path to the git bundle file
  - git_ref: The git reference to checkout (branch, tag, or commit)
  - app_dir: (Optional) Path to the application directory, defaults to "./app"
  
  Returns:
  - {:ok, results} on success, where results is a map of job names to job execution results
  - {:error, reason} on failure
  """
  def process_git_repo_and_actor_plan(bundle_path, app_dir \\ "./app") do
    require Logger

    git_ref = NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.get_ref_from_bundle(bundle_path)

    #Logger.info("Starting process_git_repo_and_actor_plan for bundle: #{bundle_path}, ref: #{git_ref}, app_dir: #{app_dir}")
    Logger.info("Pull Request Repository: #{bundle_path}")
    Logger.info("Pull Request Source Ref: #{git_ref}")

    # Check if the git_ref is one of the restricted values
    # Clean and normalize the git_ref for safer comparison
    clean_git_ref = git_ref |> String.trim() |> String.downcase()
    
    if clean_git_ref in ["main", "master", "head"] do
      Logger.error("Cannot process restricted git ref: #{git_ref}")
      raise "Restricted git reference detected: #{git_ref} is not allowed"
    end
    
    # Set up the git repository
    with {:ok, tmp_dir} <- NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.setup_repo(bundle_path, git_ref, app_dir),
         _ <- (NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.select_branch(tmp_dir, "main"); :ok),
         #_ <- (Logger.info("Repository setup complete, searching for actor plan in: #{tmp_dir}"); :ok),
         actor_file when not is_nil(actor_file) <- NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.get_actor_file_path(tmp_dir),
         #_ <- (Logger.info("Found actor plan file at: #{actor_file}"); :ok),
         {:ok, plan} <- NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.load_actor_plan(actor_file),
         #_ <- (Logger.info("Loaded actor plan with #{length(plan.jobs)} job(s)"); :ok),
         _ <- (NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.select_branch(tmp_dir, git_ref); :ok),
         {:ok, results} <- NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.execute_plan(plan, tmp_dir) do
      # Return the execution results
      #Logger.info("Actor plan execution completed successfully")
      {:ok, results}
    else
      nil ->
        Logger.error("Actor plan file not found in the repository")
        {:error, :actor_plan_not_found}
      {:error, reason} = error ->
        Logger.error("Process failed with reason: #{inspect(reason)}")
        error
    end
  end

  # Helper function to list directory structure for debugging
  defp list_directory_structure(dir) do
    require Logger
    
    Logger.info("Listing directory structure for: #{dir}")
    
    # Use System.cmd to run find command to list all files and directories
    case System.cmd("find", [dir, "-type", "f", "-o", "-type", "d"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Directory listing: \n#{output}")
      {error, _} ->
        Logger.error("Failed to list directory: #{error}")
    end
  end

  defmodule Job do
    @moduledoc """
    Represents a job to be executed by the CI/CD system.
    """
    
    @type state :: :pending | :running | :completed | :failed

    @type t :: %__MODULE__{
      job_id: String.t(),                    # Unique identifier for the job
      repository_url: String.t(),            # URL of the git repository
      commit_hash: String.t(),               # Commit to build
      build_script: String.t(),              # User-provided build commands
      script_path: String.t(),               # Path where the templated bash script will be written
      worker_id: String.t() | nil,           # ID of the worker running this job
      state: state(),                        # Current state of the job
      started_at: DateTime.t() | nil,        # When the job started running
      completed_at: DateTime.t() | nil,      # When the job finished
      build_artifacts: list(String.t()),     # Paths to generated artifacts
      environment: map()                     # Environment variables for the build
    }

    defstruct [
      :job_id,
      :repository_url,
      :commit_hash,
      :build_script,
      :script_path,
      :worker_id,
      state: :pending,
      started_at: nil,
      completed_at: nil,
      build_artifacts: [],
      environment: %{}
    ]
  end

  defmodule JobRunner do
    @moduledoc """
    Manages the execution of jobs in separate tasks.
    """
    use GenServer
    require Logger

    # Client API

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def submit_job(%Job{} = job) do
      GenServer.call(__MODULE__, {:submit_job, job})
    end

    def get_running_jobs do
      GenServer.call(__MODULE__, :get_running_jobs)
    end

    # Server Callbacks

    @impl true
    def init(_opts) do
      # Store both running and completed jobs
      {:ok, %{running_jobs: %{}, completed_jobs: %{}}}
    end

    @impl true
    def handle_call({:submit_job, job}, _from, state) do
      # Use Task.async instead of spawn_monitor - this provides better integration
      # with OTP and ensures messages will be delivered properly
      task = Task.async(fn -> execute_job(job) end)
      
      # Store the running job with task reference
      updated_job = %{job | state: :running, started_at: DateTime.utc_now()}
      new_state = put_in(state.running_jobs[job.job_id], {task.pid, task.ref, updated_job})
      
      {:reply, {:ok, task.pid}, new_state}
    end

    @impl true
    def handle_call(:get_running_jobs, _from, state) do
      # Return filtered running jobs map
      running_jobs = Map.new(state.running_jobs, fn {job_id, {pid, _ref, job}} -> 
        {job_id, {pid, job}} 
      end)
      
      {:reply, running_jobs, state}
    end

    @impl true
    def handle_info({ref, result}, %{running_jobs: running_jobs} = state) do
      # This clause handles successful task completion
      # Find the job corresponding to this task reference
      job_entry = Enum.find(running_jobs, fn {_, {_pid, task_ref, _job}} -> task_ref == ref end)
      
      # The Task is done, so we can demonitor it
      Process.demonitor(ref, [:flush])
      
      state = case job_entry do
        {job_id, {_pid, _ref, job}} ->
          # Update job to completed state
          completed_job = %{job | state: :completed, completed_at: DateTime.utc_now()}
          Logger.info("Job #{job_id} completed successfully: #{inspect(result)}")
          
          # Remove from running_jobs and add to completed_jobs
          %{
            state | 
            running_jobs: Map.delete(running_jobs, job_id),
            completed_jobs: Map.put(state.completed_jobs, job_id, completed_job)
          }
          
        nil ->
          # Task not found in our records - shouldn't happen, but handle gracefully
          Logger.warn("Task #{inspect(ref)} completed but job not found in running jobs")
          state
      end
      
      {:noreply, state}
    end

    @impl true
    def handle_info({:DOWN, ref, :process, pid, reason}, %{running_jobs: running_jobs} = state) do
      # This clause handles task failures
      job_entry = Enum.find(running_jobs, fn {_, {job_pid, task_ref, _job}} -> 
        task_ref == ref && job_pid == pid 
      end)
      
      state = case job_entry do
        {job_id, {_pid, _ref, job}} ->
          # Update job to failed state
          failed_job = %{job | state: :failed, completed_at: DateTime.utc_now()}
          Logger.warn("Job #{job_id} failed with reason: #{inspect(reason)}")
          
          # Remove from running_jobs and add to completed_jobs
          %{
            state | 
            running_jobs: Map.delete(running_jobs, job_id),
            completed_jobs: Map.put(state.completed_jobs, job_id, failed_job)
          }
          
        nil ->
          Logger.warn("Process crashed but job not found: #{inspect(pid)}, reason: #{inspect(reason)}")
          state
      end
      
      {:noreply, state}
    end

    # Private Functions

    @doc """
    Submits a job from a job definition.
    """
    def submit_job_from_definition(job_def, input_values \\ %{}) do
      # Convert the job definition to a Job struct
      job = NautilusInstituteContinuousIntegrationAndContinuousDelivery.JobDefinition.to_job(job_def)
      
      # Add any input values to the environment
      job = %{job | environment: Map.merge(job.environment, input_values)}
      
      # Submit the job
      submit_job(job)
    end

    defp execute_job(job) do
      Logger.info("Executing job #{job.job_id}")
      
      # Create directory for the script if it doesn't exist
      script_dir = Path.dirname(job.script_path)
      File.mkdir_p!(script_dir)
      
      # The REPO_ROOT is now set via inputs by execute_plan
      
      # Render the build script template using EEx
      rendered_script = render_template(job.build_script, job.environment)
      
      # If REPO_ROOT is in the environment, explicitly set it at the start of the script
      repo_root = Map.get(job.environment, "REPO_ROOT")
      rendered_script = if repo_root do
        "#!/bin/bash\nexport REPO_ROOT=\"#{repo_root}\"\n" <> rendered_script
      else
        rendered_script
      end
      
      # Write the rendered script to the script path
      File.write!(job.script_path, rendered_script)
      
      # Make the script executable
      File.chmod!(job.script_path, 0o755)
      
      # Print script content for sanity check
      script_content = File.read!(job.script_path)
      #Logger.info("Script content:\n#{script_content}")

      log_path = "/ci/#{job.job_id}_#{:erlang.phash2(make_ref())}.log"
      
      # Execute the script in a new OS process
      #Logger.info("Executing script: #{job.script_path}")

      # Execute the script with bash
      port = Port.open({:spawn, "bash #{job.script_path} >> #{log_path} 2>&1"}, [:binary, :exit_status])
      
      # Wait for the script to complete and get the exit status
      exit_status = receive do
        {^port, {:exit_status, status}} ->
          Logger.info("Job #{job.job_id} completed with status: #{status}")
          status
      end

      # Read the log file
      log_content = File.read!(log_path)
      Logger.info(log_content)
      
      # Return success or error based on exit status
      if exit_status == 0 do
        {:ok, job.job_id}
      else
        Logger.error("Job #{job.job_id} failed with exit status: #{exit_status}")
        {:error, {:script_failed, exit_status}}
      end
    end
    
    # Helper to render templates
    defp render_template(template, bindings) do
      require Logger
      #Logger.info("Rendering template: #{inspect(template)}")
      
      # Ensure template is a string
      template = cond do
        is_binary(template) -> template
        is_list(template) -> List.to_string(template)
        true -> 
          Logger.error("Invalid template type: #{inspect(template)}")
          "echo 'Invalid template type'"
      end
      
      # Sanitize all input values to only allow alphanumeric, space, -, /, _
      sanitized_bindings = Enum.map(bindings, fn
        {k, v} when is_binary(v) -> 
          sanitized = sanitize_value(v)
          {k, sanitized}
        {k, v} when is_list(v) -> 
          # Try to convert to string if it's a charlist
          try do
            string_v = List.to_string(v)
            sanitized = sanitize_value(string_v)
            if sanitized != string_v do
              Logger.warn("Sanitized charlist value for #{inspect(k)}: '#{string_v}' -> '#{sanitized}'")
            end
            {k, sanitized}
          rescue
            _ -> 
              # Not a charlist, return as is
              {k, v}
          end
        pair -> pair  # Keep other types unchanged
      end)
      
      # Convert bindings map to keyword list for EEx
      bindings_list = Enum.map(sanitized_bindings, fn
        {k, v} when is_list(k) -> {String.to_atom(List.to_string(k)), v}
        {k, v} when is_binary(k) -> {String.to_atom(k), v}
        {k, v} -> {k, v}
      end)
      
      # Create a safe template with shebang
      script_template = "#!/bin/bash\n" <> template
      
      try do
        # Compile the template first to validate it
        compiled = EEx.compile_string(script_template)
        #Logger.info("Template compiled successfully")
        
        # Evaluate with bindings
        result = EEx.eval_string(script_template, bindings_list)
        #Logger.info("Template rendered successfully")
        result
      rescue
        e ->
          Logger.error("Failed to render template: #{inspect(e)}")
          error_message = Exception.message(e)
          Logger.error("Error message: #{error_message}")
          
          # Create a safe fallback script
          """
          #!/bin/bash
          echo 'Error: Template rendering failed - #{error_message}'
          echo 'Template: #{String.replace(template, "\"", "\\\"")}'
          echo 'Bindings: #{inspect(bindings_list)}'
          exit 1
          """
      end
    end
    defp sanitize_value_regex_unsafe(value) when is_binary(value) do
      # Use a regex to keep only allowed characters
      Regex.replace(~r/[^a-zA-Z0-9\s\-\/\_#]/, value, "")
    end
    
    # Helper function to sanitize values to only allow alphanumeric, space, -, /, and _
    defp sanitize_value(value) when is_binary(value) do
      # Validate each character strictly
      allowed_chars = ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -/_#."
      
      # Check if any character is not allowed
      invalid_chars = for <<c::utf8 <- value>>, not Enum.member?(allowed_chars, c), do: <<c::utf8>>
      
      if invalid_chars != [] do
        # Found invalid characters, remove them
        Logger.warn("🚨🚨🚨 SECURITY WARNING: Found invalid characters: #{invalid_chars |> Enum.uniq() |> Enum.join(", ")} in '#{value}'")
        # Instead of filtering out invalid characters, set the value to an empty string
        sanitized_value = ""
        
        # No need to check for remaining invalid characters since we're using an empty string
        # which is guaranteed to be valid
        
        sanitized_value
      else
        # All characters are valid, return the value
        value
      end
    end
    defp sanitize_value(value), do: value
  end

  defmodule DevTest do
    @moduledoc """
    Development testing utilities for the CI/CD system.
    For testing purposes only - not for production use.
    """

    @doc """
    Creates a new job with the given parameters or defaults.
    """
    def create_test_job(opts \\ []) do
      job_id = Keyword.get(opts, :job_id, "test-#{:rand.uniform(1000)}")
      script_path = Keyword.get(opts, :script_path, "/tmp/ci/jobs/#{job_id}/build.sh")
      
      %Job{
        job_id: job_id,
        repository_url: Keyword.get(opts, :repository_url, "https://github.com/nautilus/test-repo"),
        commit_hash: Keyword.get(opts, :commit_hash, "main"),
        build_script: Keyword.get(opts, :build_script, "echo 'test build' && sleep 5"),
        script_path: script_path,
        worker_id: Keyword.get(opts, :worker_id, "worker-#{:rand.uniform(10)}"),
        environment: Keyword.get(opts, :environment, %{"TEST" => "true"})
      }
    end

    @doc """
    Submits a test job to the runner and returns the job information.
    """
    def submit_test_job(opts \\ []) do
      job = create_test_job(opts)
      case JobRunner.submit_job(job) do
        {:ok, pid} -> 
          IO.puts("Submitted job #{job.job_id} (PID: #{inspect(pid)})")
          {job, pid}
        error -> 
          IO.puts("Failed to submit job: #{inspect(error)}")
          error
      end
    end

    @doc """
    Creates and submits multiple test jobs in rapid succession.
    Useful for testing concurrent job handling.
    """
    def submit_concurrent_jobs(count \\ 5, base_opts \\ []) do
      1..count
      |> Enum.map(fn i ->
        opts = Keyword.merge(base_opts, [
          job_id: "concurrent-#{i}",
          script_path: "/ci/jobs/concurrent-#{i}/build.sh"
        ])
        Task.async(fn -> submit_test_job(opts) end)
      end)
      |> Task.await_many(30_000)
    end

    @doc """
    Submits two jobs that could potentially interfere with each other.
    Useful for testing job isolation and security measures.
    """
    def submit_conflicting_jobs do
      job_id = "test-#{:rand.uniform(1000)}"
      script_path = "/ci/jobs/#{job_id}/build.sh"
      
      job1 = create_test_job(
        job_id: job_id,
        script_path: script_path,
        build_script: "echo 'job1' && sleep 10"
      )
      
      job2 = create_test_job(
        job_id: job_id,  # Same job_id
        script_path: script_path,  # Same script path
        build_script: "echo 'job2' && sleep 5"
      )
      
      {submit_test_job(job1), submit_test_job(job2)}
    end
  end

  defmodule JobDefinition do
    @moduledoc """
    Handles loading and parsing of job definitions from XML files.
    """
    require Logger

    @doc """
    Loads a job definition from an XML file.
    Returns {:ok, job_definition} on success or {:error, reason} on failure.
    """
    def load(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          # Preprocess the XML to fix any rendering issues with name tags
          fixed_content = content 
          
          parse_xml(fixed_content)
        {:error, reason} ->
          Logger.error("Failed to read job definition file: #{file_path}, reason: #{reason}")
          {:error, reason}
      end
    end

    @doc """
    Loads all job definitions from a directory.
    Returns a list of job definitions.
    """
    def load_all(directory) do
      directory
      |> Path.join("**/*.xml")
      |> Path.wildcard()
      |> Enum.map(&load/1)
      |> Enum.filter(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      |> Enum.map(fn {:ok, definition} -> definition end)
    end

    @doc """
    Parses an XML job definition.
    Returns {:ok, job_definition} on success or {:error, reason} on failure.
    """
    def parse_xml(xml_content) do
      try do
        # Print the XML content
        #IO.puts("XML content: #{xml_content}")
        
        # Parse XML using xmerl instead of erlsom
        {xml_element, _} = xml_content 
          |> String.to_charlist()
          |> :xmerl_scan.string()
        
        # Convert to simpler format and parse
        [root_element] = :xmerl_lib.remove_whitespace([:xmerl_lib.simplify_element(xml_element)])
        job_def = parse_simplified_job_element(root_element)
        
        {:ok, job_def}
      rescue
        e ->
          Logger.error("Exception while parsing XML: #{inspect(e)}")
          {:error, :parse_failed}
      end
    end
    
    # Parse the simplified job element
    defp parse_simplified_job_element({:job, attrs, children}) do
      # Debug: Print children elements
      #IO.puts("Children elements:")
      #Enum.each(children, fn element -> 
      #  IO.puts("  #{inspect(element)}")
      #end)
      
      # Extract name from children
      name = extract_child_text(children, :name)
      #IO.puts("Name from :name tag: #{inspect(name)}")
      
      # If name not found, try looking for "n" tag
      name = if name == "", do: extract_child_text(children, :n), else: name
      #IO.puts("Final name: #{inspect(name)}")
      
      script = extract_child_text(children, :script)
      env_vars = parse_simplified_env_vars(children)
      inputs = parse_simplified_value_defs(children, :input)
      outputs = parse_simplified_value_defs(children, :output)
      imports = parse_simplified_imports(children)
      
      %{
        name: name,
        script_template: script,
        env_vars: env_vars,
        inputs: inputs,
        outputs: outputs,
        imports: imports
      }
    end
    
    # Extract text from a child element
    defp extract_child_text(children, element_name) do
      text = children
      |> Enum.find_value("", fn
        {^element_name, _, [text]} when is_binary(text) -> text
        {^element_name, _, text} when is_binary(text) -> text
        {^element_name, _, [char_list]} when is_list(char_list) -> List.to_string(char_list)
        {^element_name, _, char_list} when is_list(char_list) -> List.to_string(char_list)
        _ -> nil
      end)
      
      # If this is a script element, replace template delimiters
      if element_name == :script do
        text
        |> String.replace("{%", "<%")
        |> String.replace("%}", "%>")
      else
        text
      end
    end
    
    # Parse environment variables
    defp parse_simplified_env_vars(children) do
      children
      |> Enum.find_value(%{}, fn
        {:env, _, vars} -> parse_simplified_var_elements(vars)
        _ -> nil
      end)
    end
    
    # Parse var elements in env
    defp parse_simplified_var_elements(elements) do
      elements
      |> Enum.reduce(%{}, fn
        {:var, attrs, [value]}, acc ->
          var_name = extract_attribute(attrs, :name)
          if var_name, do: Map.put(acc, var_name, value), else: acc
        _, acc -> 
          acc
      end)
    end
    
    # Extract attribute value
    defp extract_attribute(attrs, attr_name) do
      Enum.find_value(attrs, nil, fn
        {^attr_name, value} -> value
        _ -> nil
      end)
    end
    
    # Parse input or output definitions
    defp parse_simplified_value_defs(children, type) do
      children
      |> Enum.filter(fn
        {^type, _, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {^type, attrs, _} -> 
        extract_attribute(attrs, :name)
      end)
      |> Enum.filter(&(&1 != nil))
    end
    
    # Parse import elements
    defp parse_simplified_imports(children) do
      children
      |> Enum.filter(fn
        {:import, _, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:import, attrs, _} -> 
        extract_attribute(attrs, :path)
      end)
      |> Enum.filter(&(&1 != nil))
    end

    @doc """
    Converts a job definition to a Job struct.
    """
    def to_job(job_def) do
      script_path = "/ci/jobs/#{job_def.name}/build.sh"
      
      # Ensure script_template is a binary string
      script_template = case job_def.script_template do
        template when is_list(template) -> List.to_string(template)
        template when is_binary(template) -> template
        _ -> ""
      end
      
      # Convert environment variables to binary strings
      env_vars = Enum.reduce(job_def.env_vars, %{}, fn {key, value}, acc ->
        # Convert key and value to binary strings if they're character lists
        key_str = if is_list(key), do: List.to_string(key), else: key
        value_str = if is_list(value), do: List.to_string(value), else: value
        Map.put(acc, key_str, value_str)
      end)
      
      %Job{
        job_id: job_def.name,
        build_script: script_template,
        script_path: script_path,
        environment: env_vars
      }
    end
  end

  defmodule JobLoader do
    @moduledoc """
    Handles loading and processing job definition files.
    """
    require Logger

    @doc """
    Loads all job definitions from a root job definition file.
    Processes imports recursively.
    Returns a map of job name to job definition.
    """
    def load_jobs(root_file) do
      Logger.info("Loading jobs from #{root_file}")
      case JobDefinition.load(root_file) do
        {:ok, root_def} ->
          # Process the root job and its imports
          jobs = %{root_def.name => root_def}
          process_imports(root_def.imports, Path.dirname(root_file), jobs)
          
        {:error, reason} ->
          Logger.error("Failed to load root job file: #{reason}")
          %{}
      end
    end

    @doc """
    Registers all jobs from a root job definition file with the JobRegistry.
    """
    def register_jobs(root_file) do
      jobs = load_jobs(root_file)
      
      # Register each job
      Enum.each(jobs, fn {_name, job_def} ->
        NautilusInstituteContinuousIntegrationAndContinuousDelivery.JobRegistry.register_job(job_def)
      end)
      
      {:ok, map_size(jobs)}
    end

    # Private functions

    defp process_imports(imports, base_dir, jobs) do
      Enum.reduce(imports, jobs, fn import_path, acc ->
        full_path = if Path.type(import_path) == :relative do
          Path.join(base_dir, import_path)
        else
          import_path
        end
        
        if String.ends_with?(full_path, "*.xml") do
          # Import all XML files in a directory
          dir = Path.dirname(full_path)
          pattern = Path.basename(full_path)
          
          Path.join(dir, pattern)
          |> Path.wildcard()
          |> Enum.reduce(acc, fn file, acc2 ->
            process_import_file(file, acc2)
          end)
        else
          # Import a single file
          process_import_file(full_path, acc)
        end
      end)
    end

    defp process_import_file(file_path, jobs) do
      case JobDefinition.load(file_path) do
        {:ok, job_def} ->
          # Add the job to our map
          jobs = Map.put(jobs, job_def.name, job_def)
          
          # Process its imports
          process_imports(job_def.imports, Path.dirname(file_path), jobs)
          
        {:error, _reason} ->
          # Skip this file
          jobs
      end
    end
  end

  defmodule JobRegistry do
    @moduledoc """
    Registry for job definitions.
    """
    use GenServer
    require Logger

    # Client API

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def register_job(job_def) do
      GenServer.call(__MODULE__, {:register, job_def})
    end

    def get_job(job_name) do
      GenServer.call(__MODULE__, {:get, job_name})
    end

    def list_jobs do
      GenServer.call(__MODULE__, :list)
    end

    # Server Callbacks

    @impl true
    def init(_opts) do
      {:ok, %{jobs: %{}}}
    end

    @impl true
    def handle_call({:register, job_def}, _from, state) do
      # Ensure job name is a binary string
      job_name = to_string(job_def.name)
      job_def = Map.put(job_def, :name, job_name)
      new_state = put_in(state.jobs[job_name], job_def)
      {:reply, :ok, new_state}
    end

    @impl true
    def handle_call({:get, job_name}, _from, state) do
      # Normalize job name to binary string
      normalized_name = to_string(job_name)
      
      # First try exact match
      result = case Map.fetch(state.jobs, normalized_name) do
        {:ok, job_def} -> {:ok, job_def}
        :error -> 
          # Try case-insensitive match if exact match fails
          case Enum.find(state.jobs, fn {k, _v} -> 
            String.downcase(to_string(k)) == String.downcase(normalized_name) 
          end) do
            {_key, job_def} -> {:ok, job_def}
            nil -> {:error, :not_found}
          end
      end
      
      {:reply, result, state}
    end

    @impl true
    def handle_call(:list, _from, state) do
      job_names = Map.keys(state.jobs)
      {:reply, job_names, state}
    end
  end

  defmodule GitRepo do
    @moduledoc """
    Handles git repository operations for the CI/CD system.
    """
    require Logger

    @doc """
    Get the ref from the bundle path

    ```
    # v2 git bundle
    c5244ec9c659de128ff81086907398cc22dbc101 refs/heads/foo
    ...
    ...
    ...

    ```

    """
    def get_ref_from_bundle(bundle_path) do
      # Read the bundle file
      {:ok, bundle_content} = File.read(bundle_path)
      
      # Parse the bundle content
      lines = String.split(bundle_content, "\n")
      
      # Get the second line (index 1)
      second_line = Enum.at(lines, 1)
      
      # Split the line by whitespace and get the second chunk
      ref = case String.split(second_line, " ") do
        [_, ref_path | _] -> 
          # Strip "refs/heads/" prefix if present
          String.replace(ref_path, ~r/^refs\/heads\//, "")
        _ -> 
          nil
      end
      
      ref
    end


    
    @doc """
    Sets up a git repository from a bundle.
    
    Takes:
    - bundle_path: Path to the git bundle file
    - git_ref: The git reference to checkout (branch, tag, or commit)
    - app_dir: The application directory to be copied to a temporary location
    
    Returns:
    - {:ok, tmp_dir_path} on success
    - {:error, reason} on failure
    """
    def setup_repo(bundle_path, git_ref, app_dir \\ "./app") do
      #Logger.info("Setting up git repository from bundle: #{bundle_path}, ref: #{git_ref}")
      
      # Create a temporary directory for the app
      tmp_dir = create_temp_dir()
      #Logger.info("Created temporary directory at: #{tmp_dir}")

      tmp_app_dir = Path.join(tmp_dir, "app")
      
      # Copy the app directory to the temp directory
      with :ok <- copy_app_dir(app_dir, tmp_dir),
           :ok <- extract_bundle(bundle_path, tmp_app_dir),
           :ok <- pull_ref(tmp_app_dir, git_ref) do
        
        #Logger.info("Successfully set up git repository at #{tmp_app_dir}")
        {:ok, tmp_app_dir}
      else
        {:error, reason} = error ->
          Logger.error("Failed to set up git repository: #{reason}")
          error
      end
    end

    @doc """
    Selects a branch in the git repository.
    """
    def select_branch(repo_dir, branch_name) do
      System.cmd("git", ["switch", branch_name], stderr_to_stdout: true)
    end

    @doc """
    Loads and parses an actor.x plan file.
    
    Returns:
    - {:ok, plan} on success, where plan is a list of job execution specifications
    - {:error, reason} on failure
    """
    def load_actor_plan(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          parse_actor_plan(content)
        {:error, reason} ->
          Logger.error("Failed to read actor plan file: #{file_path}, reason: #{reason}")
          {:error, reason}
      end
    end


    @doc """
    Parses the content of an actor.x file.
    
    Returns:
    - {:ok, plan} on success
    - {:error, reason} on failure
    """
    def parse_actor_plan(content) do
      try do
        # Parse XML using xmerl
        {xml_element, _} = content 
          |> String.to_charlist()
          |> :xmerl_scan.string()
        
        # Convert to simpler format and parse
        [root_element] = :xmerl_lib.remove_whitespace([:xmerl_lib.simplify_element(xml_element)])
        plan = parse_simplified_actor_element(root_element)
        
        {:ok, plan}
      rescue
        e ->
          Logger.error("Exception while parsing actor plan XML: #{inspect(e)}")
          {:error, :parse_failed}
      end
    end
    
    @doc """
    Get the path to the actor.x file in the given app directory.
    Returns the path if the file exists, nil otherwise.
    """
    def get_actor_file_path(app_tmp_dir) do
      require Logger
      
      # Check for .nautilus directory
      nautilus_dir = Path.join(app_tmp_dir, ".nautilus")
      #Logger.info("Checking for .nautilus directory at: #{nautilus_dir}")
      
      if File.exists?(nautilus_dir) do
        #Logger.info(".nautilus directory exists")
        
        # Check for plan directory
        plan_dir = Path.join(nautilus_dir, "plan")
        #Logger.info("Checking for plan directory at: #{plan_dir}")
        
        if File.exists?(plan_dir) do
          #Logger.info("plan directory exists")
          
          # Check for actor.x file
          actor_path = Path.join(plan_dir, "actor.x")
          #Logger.info("Checking for actor.x file at: #{actor_path}")
          
          if File.exists?(actor_path) do
            #Logger.info("actor.x file found at: #{actor_path}")
            actor_path
          else
            #Logger.error("actor.x file not found at: #{actor_path}")
            # List contents of plan directory for debugging
            #case File.ls(plan_dir) do
            #  {:ok, files} -> 
            #    #Logger.info("Contents of plan directory: #{inspect(files)}")
            #  {:error, reason} -> 
            #    #Logger.error("Failed to list plan directory: #{inspect(reason)}")
            #end
            nil
          end
        else
          #Logger.error("plan directory not found at: #{plan_dir}")
          # List contents of .nautilus directory for debugging
          #case File.ls(nautilus_dir) do
          #  #{:ok, files} -> 
          #    #Logger.info("Contents of .nautilus directory: #{inspect(files)}")
          #  {:error, reason} -> 
          #    #Logger.error("Failed to list .nautilus directory: #{inspect(reason)}")
          #    nil
          #end
          nil
        end
      else
        #Logger.error(".nautilus directory not found at: #{nautilus_dir}")
        # List contents of app_tmp_dir for debugging
        case File.ls(app_tmp_dir) do
          {:ok, files} -> 
            Logger.info("Contents of app_tmp_dir: #{inspect(files)}")
          {:error, reason} -> 
            Logger.error("Failed to list app_tmp_dir: #{inspect(reason)}")
        end
        nil
      end
    end
    
    # Private functions
    def execute_plan(plan, repo_path) do
      #Logger.info("Executing actor plan with #{length(plan.jobs)} jobs")
      
      Logger.info("Repository path for jobs: #{repo_path}")
      
      results = Enum.reduce_while(plan.jobs, %{}, fn job_spec, acc ->
        # Add REPO_ROOT to the job inputs
        job_spec = update_in(job_spec.inputs, fn inputs ->
          Map.put(inputs, "REPO_ROOT", repo_path)
        end)
        
        case execute_job_spec(job_spec) do
          {:ok, result} ->
            {:cont, Map.put(acc, job_spec.job_name, result)}
          {:error, reason} = error ->
            Logger.error("Failed to execute job #{job_spec.job_name}: #{reason}")
            if plan.fail_fast do
              {:halt, error}
            else
              {:cont, Map.put(acc, job_spec.job_name, error)}
            end
        end
      end)
      
      if is_map(results) do
        {:ok, results}
      else
        results # This would be the error that caused the halt
      end
    end
    defp extract_attribute(attrs, attr_name) do
      Enum.find_value(attrs, "", fn
        {^attr_name, value} -> value
        _ -> nil
      end)
    end

    @doc """
    Sanitizes job input values by replacing any matches to the given regex with asterisks.
    
    ## Parameters
    
    - `job_spec` - The job specification containing inputs to sanitize
    - `pattern` - The regex pattern to match against input values
    
    ## Returns
    
    A new job spec with sanitized input values
    """
    def sanitize_inputs(job_spec, pattern) do
      sanitized_inputs = Enum.map(job_spec.inputs, fn {key, value} ->
        sanitized_value = if is_binary(value) do
          start_time = System.monotonic_time()
          is_match = Regex.match?(pattern, value)
          match_time = System.monotonic_time()
          #Logger.info("Regex match check for '#{value}' took #{System.convert_time_unit(match_time - start_time, :native, :microsecond)} μs")
          
          if is_match do
            replace_start = System.monotonic_time()
            result = Regex.replace(pattern, value, "---")
            replace_end = System.monotonic_time()
            #Logger.info("Regex replace for '#{value}' took #{System.convert_time_unit(replace_end - replace_start, :native, :microsecond)} μs")
            result
          else
            value
          end
        else
          value
        end
        {key, sanitized_value}
      end)
      |> Enum.into(%{})

      #IO.puts("Sanitized inputs: #{inspect(sanitized_inputs)}")
      
      Map.put(job_spec, :inputs, sanitized_inputs)
    end
    
    defp execute_job_spec(job_spec) do
      #IO.puts("Loaded job definitions.")

      # Display available jobs
      job_names = JobRegistry.list_jobs()
      
      if job_names != [] do
        #IO.puts("\nAvailable jobs:")
        #Enum.each(job_names, &IO.puts("  - #{&1}"))
      end

      # Log the job spec and inputs
      #Logger.info("Executing job: #{job_spec.job_name}")
      #Logger.info("Job inputs: #{inspect(job_spec.inputs)}")

      # Sanitize the job inputs
      sanitized_job_spec = job_spec
      
      # Apply the default regex pattern for sensitive data
      sanitized_job_spec = sanitize_inputs(sanitized_job_spec, ~r/(password|secret|token)[^\s]*/)
      
      # Check if job has a custom censor regex defined as a special input parameter
      # Try both string and character list versions of the key
      custom_regex_input = Map.get(job_spec.inputs, "censor-regex") || 
                           Map.get(job_spec.inputs, ~c"censor-regex")
                           
      #Logger.info("Looking for censor regex, found: #{inspect(custom_regex_input)}")
      
      if custom_regex_input && custom_regex_input != "" do
        # Try to compile the regex, and apply it if valid
        try do
          start_time = System.monotonic_time()
          custom_regex = Regex.compile!(custom_regex_input)
          compile_time = System.monotonic_time()
          #Logger.info("Custom regex compilation took #{System.convert_time_unit(compile_time - start_time, :native, :microsecond)} μs")
          #Logger.info("Applying custom censor regex from inputs: #{custom_regex_input}")
          sanitized_job_spec = sanitize_inputs(sanitized_job_spec, custom_regex)
          end_time = System.monotonic_time()
          #Logger.info("Custom regex sanitization took #{System.convert_time_unit(end_time - compile_time, :native, :microsecond)} μs")
          
          # Remove the censor-regex input as it's not meant to be passed to the actual job
          # Remove both string and charlist versions to be safe
          sanitized_job_spec = Map.update!(sanitized_job_spec, :inputs, fn inputs ->
            inputs
            |> Map.delete("censor-regex")
            |> Map.delete(~c"censor-regex")
          end)
        rescue
          e ->
            Logger.error("Invalid custom censor regex input: #{inspect(e)}")
        end
      end
      
      
      # Look up the job definition in the registry
      case JobRegistry.get_job(job_spec.job_name) do
        {:ok, job_def} ->
          #Logger.info("Found job definition for #{job_spec.job_name}")
          # Submit the job with the sanitized inputs
          JobRunner.submit_job_from_definition(job_def, sanitized_job_spec.inputs)
          
        {:error, reason} = error ->
          Logger.error("Failed to find job definition for #{job_spec.job_name}: #{reason}")
          error
      end
    end

    defp parse_job_element({:job, attrs, children}) do
      # Get the job name
      job_name = extract_attribute(attrs, :name)
      
      # Ensure job_name is a binary string
      job_name = if is_list(job_name), do: List.to_string(job_name), else: to_string(job_name)
      
      # Parse inputs
      inputs = children
        |> Enum.filter(fn
          {:input, _, _} -> true
          _ -> false
        end)
        |> Enum.map(&parse_input_element/1)
        |> Enum.into(%{})
      
      %{
        job_name: job_name,
        inputs: inputs
      }
    end
    
    defp parse_input_element({:input, attrs, content}) do
      name = extract_attribute(attrs, :name)
      value = case content do
        [value] when is_binary(value) -> value
        value when is_binary(value) -> value
        [char_list] when is_list(char_list) -> List.to_string(char_list)
        char_list when is_list(char_list) -> List.to_string(char_list)
        _ -> ""
      end
      
      {name, value}
    end
    
    defp parse_boolean_attr(attrs, attr_name, default) do
      case extract_attribute(attrs, attr_name) do
        "true" -> true
        "false" -> false
        _ -> default
      end
    end

    defp parse_simplified_actor_element({:actor, attrs, children}) do
      # Extract general plan attributes
      fail_fast = parse_boolean_attr(attrs, :fail_fast, false)
      
      # Parse jobs
      jobs = children
        |> Enum.filter(fn
          {:job, _, _} -> true
          _ -> false
        end)
        |> Enum.map(&parse_job_element/1)
      
      %{
        fail_fast: fail_fast,
        jobs: jobs
      }
    end
    
    defp create_temp_dir do
      # Create a unique temporary directory
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      random = :rand.uniform(10000)
      tmp_dir = "/ci/nautilus_app_#{timestamp}_#{random}"
      
      File.mkdir_p!(tmp_dir)
      tmp_dir
    end
    
    defp copy_app_dir(app_dir, tmp_dir) do
      #Logger.info("Copying app directory from #{app_dir} to #{tmp_dir}")
      
      try do
        # Use System.cmd to run cp -r
        {_, 0} = System.cmd("cp", ["-r", app_dir, tmp_dir], stderr_to_stdout: true)
        #{_, 0} = System.cmd("rsync", ["-av", "--mkpath", app_dir, tmp_dir], stderr_to_stdout: true)
        :ok
      rescue
        e ->
          Logger.error("Failed to copy app directory: #{inspect(e)}")
          {:error, :copy_failed}
      end
    end
    
    defp extract_bundle(bundle_path, tmp_dir) do
      #Logger.info("Extracting git bundle at #{bundle_path} into #{tmp_dir}")
      
      try do
        # Change to the temporary directory
        File.cd!(tmp_dir)
        
        # Create a new git repository
        {_, 0} = System.cmd("git", ["init"], stderr_to_stdout: true)
        
        # Add the bundle as a remote
        System.cmd("git", ["remote", "remove", "origin"], stderr_to_stdout: true)
        # Add the bundle as a remote
        {_, 0} = System.cmd("git", ["remote", "add", "origin", bundle_path], stderr_to_stdout: true)
        
        # Fetch the remote
        {_, 0} = System.cmd("git", ["fetch", "origin"], stderr_to_stdout: true)
        
        :ok
      rescue
        e ->
          Logger.error("Failed to extract git bundle: #{inspect(e)}")
          {:error, :bundle_extraction_failed}
      end
    end
    
    defp pull_ref(repo_dir, git_ref) do
      # Set git_ref with a null byte at the start
      #git_ref = <<0>> <> to_string(git_ref)
      #Logger.info("Pulling ref: #{git_ref} in #{repo_dir}")
      
      try do
        # Change to the repository directory
        File.cd!(repo_dir)

        System.cmd("git", ["switch", "-C", git_ref], stderr_to_stdout: true)
        
        {_, 0} = System.cmd("git", ["pull", "origin", git_ref], stderr_to_stdout: true)
        
        :ok
      rescue
        e ->
          Logger.error("Failed to checkout git ref: #{inspect(e)}")
          {:error, :checkout_failed}
      end
    end
  end

end