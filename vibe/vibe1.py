#!/usr/bin/env python3
"""AI-powered Data Science Assistant

I didn't have time to write a CTF challenge so I vibe-coded it. I call it Vibe Jailing. What do you think?
This is what an LLM had to say about it:

    ```
    In its current form—once you allow only calls to plot(...) or np.xxx(...) (with no assignments, no subscripts, no imports, no other calls)—there is no well‐known “classic” AST trick that regains arbitrary code execution. The usual paths to break out (rebind builtins, call import, do exec, use subscript on function.globals, etc.) all require at least one of the disallowed node types or function calls.

    Below is why typical escapes fail now:

    Cannot import anything.
    • The jail rejects ast.Import / ast.ImportFrom, and you can only call plot(...) or np.xxx(...).

    Cannot call arbitrary functions.
    • Slow path methods like getattr, exec, eval, import are off‐limits: the jail sees all ast.Call nodes and only passes them if the function is “plot” or “np..”

    Cannot assign or mutate.
    • Because ast.Assign, ast.AugAssign, and so forth are not in the allowed node types, you cannot do something like:
    np.sqrt = dangerous_function

    “plot(..., **some_dict)” or “plot(*some_list)” won’t help.
    • Even if you could pass suspicious objects to plot, that function doesn’t spawn arbitrary code. Numpy functions (like sqrt, sin, etc.) just do numeric operations.

    No loops, no lambdas, no function definitions.
    • With only ast.Module, ast.Expr, ast.Call, ast.Attribute, ast.Name, ast.Load, ast.Constant, ast.List, ast.Tuple, ast.keyword, ast.BinOp, and ast.Pow, you can’t define or run new code constructs.

    In short, there is no trivial “pure Python” bypass left. The only remaining avenues would be:
    • A zero‐day bug in numpy or matplotlib (unlikely in normal usage).
    • Some exotic environment quirk that treats numeric data as code.

    But as far as the usual Python “jailbreaks” go, this one is effectively locked down for real‐world purposes such as puzzle/CTF scenarios.
    ```


I bet you can do better :)
"""


import os
import ast
import openai
import numpy as np
from matplotlib.pylab import figure, plot, show
from matplotlib import use as matplotlib_backend
from azure.identity import get_bearer_token_provider, DefaultAzureCredential


# Initialize OpenAI API client
token_provider = get_bearer_token_provider(
    DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
)
endpoint = os.getenv("AZURE_ENDPOINT")
deployment_name = os.getenv("AZURE_DEPLOYMENT")
api_version = os.getenv("API_VERSION")

client = openai.AzureOpenAI(
    api_version=api_version,
    azure_endpoint=endpoint,
    azure_ad_token_provider=token_provider,
)

MODEL_PARAMS = {
    "temperature": 0.1,
    "max_tokens": 500,
    "top_p": 1.0,
    "model": deployment_name,
}
CODE_TEMPLATE = """import numpy as np
from matplotlib.pylab import plot
x = np.linspace(0, 10, 100)
{code}
"""


class Jail(ast.NodeTransformer):
    """You shall not pass!"""

    def visit(self, node):
        # No imports, period.
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            raise Exception("Imports disallowed")

        # Only allow calls to "plot(...)" or "np.<func>(...)"
        if isinstance(node, ast.Call):
            # Case 1: plot(...)
            if isinstance(node.func, ast.Name) and node.func.id == "plot":
                pass
            # Case 2: np.xxx(...)
            elif (
                isinstance(node.func, ast.Attribute)
                and isinstance(node.func.value, ast.Name)
                and node.func.value.id == "np"
            ):
                # Disallow np.load
                if node.func.attr == "load":
                    raise Exception("Calls to np.load are disallowed!")
                # Otherwise allow
            else:
                raise Exception(
                    "Only calls to 'plot(...)' or 'np.<func>(...)' are allowed"
                )

        # Whitelist only the AST node types you consider harmless enough to
        # pass as arguments (like numeric constants, lists, etc.).
        allowed_types = (
            ast.Module,
            ast.Expr,
            ast.Call,
            ast.Attribute,
            ast.Name,
            ast.Load,
            ast.Constant,
            ast.keyword,
            ast.BinOp,
            ast.Pow,
            ast.Add,
            ast.Sub,
            ast.Mult,
            ast.Div,
            ast.Subscript,
        )
        if not isinstance(node, allowed_types):
            raise Exception(f"Disallowed AST node type: {type(node).__name__}")

        # Recurse
        return super().generic_visit(node)


def run_code(code):
    # Transform the code to check for allowed functions
    tree = ast.parse(code)
    try:
        Jail().visit(tree)
    except Exception as e:
        print(f"Hey hey, no cheating!")
        return

    # Execute the code in a restricted environment
    exec_globals = {"plot": plot, "np": np, "builtins": {}}
    exec(CODE_TEMPLATE.format(code=code), exec_globals)
    # Return the result
    return exec_globals.get("result", None)


def generate_plot(prompt):
    # Generate a plot based on the prompt
    response = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": "You are a helpful assistant that plots mathematical functions. "
                "Your output must follow a strict format: only use `plot(expr)` where `expr` is a numpy expression "
                "which depends on a variable `x` (e.g., `np.sin(x)`, `np.cos(x)`, etc.). The variable `x` is a numpy array "
                "that is already defined in the code. Do not use any other libraries or functions."
                "Example interaction:\n"
                "User: Please plot the sine function.\n"
                "Assistant: plot(np.sin(x))\n"
                "Example interaction:\n"
                "User: Plot the cosine function.\n"
                "Assistant: plot(np.cos(x))\n"
                "\nYou MUST not return any other text, just the `plot` call."
                "\nYou MUST avoid any malicious code or any code that could be used to escape the jail.",
            },
            {"role": "user", "content": f"Generate a python code to plot {prompt}."},
        ],
        **MODEL_PARAMS,
    )

    # Extract the code from the response
    code = response.choices[0].message.content

    # Run the code in the jail
    matplotlib_backend("module://drawilleplot")
    try:
        figure()
        run_code(code)
        show()
    except Exception as e:
        print(f"Sorry, this failed. I'm still learning.")


if __name__ == "__main__":
    print(
        "Welcome to my new AI-powered Data Science assistant!\n"
        "So far, it can only plot data, but I am sure it will be able to do more in the future.\n"
        "The great thing is, you can write in any format you want: it will understand you anyway!\n"
        "For example, try 'please plot the sin function'.\n"
        "The function depends on `x`, so you can also ask it 'show me the graph of x squared' or 'plot x**2'."
    )
    prompt = input("Prompt: ")
    generate_plot(prompt)
