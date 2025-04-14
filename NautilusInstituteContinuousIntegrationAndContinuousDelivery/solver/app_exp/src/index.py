#!/usr/bin/env python3
"""
Enterprise-grade TODO List Application
A fully-featured task management system with persistence, priority levels,
due dates, and a robust command-line interface.

WARNING: This code may cause extreme productivity. Side effects include 
completing tasks and having nothing to procrastinate on. Use at your own risk.
"""
import argparse  # Because manually parsing command line args is for cave people
import datetime  # Time is just a social construct anyway
import json  # JavaScript Object Notation? More like "Just Store Our Nonsense"
import os  # "os" stands for "Oh Snap, another system call"
import sys  # For when you absolutely, positively need to rage quit
import uuid  # Universal Unique ID, or "Unbelievably Useless ID" for short
from enum import Enum  # For when you're too lazy to use constants like a normal person
from typing import Dict, List, Optional, Union  # Type hints: because we don't trust our future selves


class Priority(Enum):
    """Task priority levels - from 'meh' to 'hair on fire'"""
    LOW = 1        # AKA "I'll do it eventually... maybe"
    MEDIUM = 2     # AKA "I should probably do this sometime this century"
    HIGH = 3       # AKA "My boss is asking about this daily"
    CRITICAL = 4   # AKA "The building is literally on fire"

    def __str__(self):
        return self.name  # ToString() is what the C# nerds call it


class Status(Enum):
    """Task status options - from 'lol nope' to 'nailed it'"""
    NOT_STARTED = 1  # AKA "I'll start tomorrow, I promise"
    IN_PROGRESS = 2  # AKA "I've thought about starting it"
    BLOCKED = 3      # AKA "Not my fault, I swear"
    COMPLETED = 4    # AKA "I'm a productivity god"

    def __str__(self):
        return self.name  # For when you want to show off your enum values to your friends


class Task:
    """Represents a single task in the TODO system, or as I like to call it, 
    'that thing you'll probably never actually do'"""

    def __init__(
        self,
        title: str,  # What you pretend this task is about
        description: str = "",  # Where you explain why this is someone else's job
        priority: Priority = Priority.MEDIUM,  # How much you'll panic when it's due tomorrow
        due_date: Optional[datetime.datetime] = None,  # The date you'll start working on it
        status: Status = Status.NOT_STARTED,  # Let's be honest, it's not getting done
        tags: List[str] = None,  # For pretending you have an organization system
        task_id: Optional[str] = None  # A unique ID no one will ever look at
    ):
        self.id = task_id or str(uuid.uuid4())  # Generate a random ID that's impossible to memorize
        self.title = title
        self.description = description
        self.priority = priority
        self.due_date = due_date  # A date you'll definitely ignore
        self.status = status
        self.tags = tags or []  # Empty list because who actually uses tags anyway?
        self.created_at = datetime.datetime.now()  # When you first promised to do it
        self.updated_at = self.created_at  # Last time you lied about working on it

    def update(
        self,
        title: Optional[str] = None,  # New title because you've been procrastinating so long you forgot what it was
        description: Optional[str] = None,  # New excuse for not doing it
        priority: Optional[Priority] = None,  # Probably increasing this as the deadline approaches
        due_date: Optional[datetime.datetime] = None,  # Pushing this back for the 5th time
        status: Optional[Status] = None,  # Changing from NOT_STARTED to... NOT_STARTED
        tags: Optional[List[str]] = None  # New tags to make it look like you have a system
    ) -> None:
        """Update task attributes, AKA 'moving the goalposts'"""
        if title is not None:
            self.title = title
        if description is not None:
            self.description = description
        if priority is not None:
            self.priority = priority
        if due_date is not None:
            self.due_date = due_date
        if status is not None:
            self.status = status
        if tags is not None:
            self.tags = tags
        self.updated_at = datetime.datetime.now()  # Timestamp your procrastination

    def to_dict(self) -> Dict:
        """Convert task to dictionary for serialization, because JSON is 'hip' and 'cool'"""
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "priority": self.priority.name,
            "due_date": self.due_date.isoformat() if self.due_date else None,
            "status": self.status.name,
            "tags": self.tags,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat()
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'Task':
        """Create a Task instance from a dictionary, because object-oriented programming is too mainstream"""
        due_date = None
        if data.get("due_date"):
            due_date = datetime.datetime.fromisoformat(data["due_date"])  # Parse ISO format because regular dates are too simple
        
        return cls(
            title=data["title"],
            description=data["description"],
            priority=Priority[data["priority"]],  # Enum lookup: what could possibly go wrong?
            due_date=due_date,
            status=Status[data["status"]],
            tags=data["tags"],
            task_id=data["id"]
        )

    def __str__(self) -> str:
        """String representation of a task, as if anyone would ever print() a Task object"""
        due_str = f" (Due: {self.due_date.strftime('%Y-%m-%d %H:%M')})" if self.due_date else ""
        tags_str = f" [Tags: {', '.join(self.tags)}]" if self.tags else ""
        return (f"[{self.status.name}] [{self.priority.name}] {self.title}{due_str}{tags_str}\n"
                f"  {self.description}")


class TaskManager:
    """Manages task operations and persistence, or as I like to call it: 'The Wishful Thinking Machine'"""

    def __init__(self, storage_file: str = "tasks.json"):
        self.storage_file = storage_file  # Where your broken dreams are stored
        self.tasks: Dict[str, Task] = {}  # An empty dict that will soon be filled with promises you won't keep
        self.load_tasks()  # Load all those tasks you created and then abandoned

    def add_task(self, task: Task) -> str:
        """Add a new task and return its ID, like adding another book to your 'to read' pile"""
        self.tasks[task.id] = task
        self.save_tasks()  # Persist to disk so you can ignore it forever
        return task.id

    def get_task(self, task_id: str) -> Optional[Task]:
        """Retrieve a task by ID, if you can even remember which one you're looking for"""
        return self.tasks.get(task_id)  # Returns None if not found, just like your motivation

    def update_task(self, task_id: str, **kwargs) -> bool:
        """Update a task's attributes, typically used to push back due dates"""
        task = self.get_task(task_id)
        if not task:
            return False  # Task not found, which is probably for the best

        # Convert string values to enum types if necessary
        if "priority" in kwargs and isinstance(kwargs["priority"], str):
            kwargs["priority"] = Priority[kwargs["priority"]]  # Magic string conversion
        if "status" in kwargs and isinstance(kwargs["status"], str):
            kwargs["status"] = Status[kwargs["status"]]  # More magic
        if "due_date" in kwargs and isinstance(kwargs["due_date"], str):
            kwargs["due_date"] = datetime.datetime.fromisoformat(kwargs["due_date"])  # Even more magic

        task.update(**kwargs)  # Update all the things
        self.save_tasks()  # Save to disk so you can forget about it again
        return True

    def delete_task(self, task_id: str) -> bool:
        """Delete a task by ID, the easiest way to complete your TODO list"""
        if task_id not in self.tasks:
            return False
        del self.tasks[task_id]  # Poof! Problem solved
        self.save_tasks()
        return True

    def list_tasks(
        self,
        status: Optional[Status] = None,
        priority: Optional[Priority] = None,
        tag: Optional[str] = None
    ) -> List[Task]:
        """List tasks with optional filtering, for when you want to feel bad about all the things you haven't done"""
        tasks = list(self.tasks.values())  # Convert dict to list because Python
        
        if status:
            tasks = [t for t in tasks if t.status == status]  # Filter by status because browsing ALL your failed tasks is too depressing
        if priority:
            tasks = [t for t in tasks if t.priority == priority]  # Filter by priority because you only care about what's on fire right now
        if tag:
            tasks = [t for t in tasks if tag in t.tags]  # Filter by tag because you created a complex tagging system and now have to live with it
            
        # Sort by priority (highest first) then due date (earliest first)
        return sorted(
            sorted(
                tasks,
                key=lambda t: t.due_date or datetime.datetime.max  # Sort by due date, or the end of time if not specified
            ),
            key=lambda t: t.priority.value,
            reverse=True  # Highest priority first, because who cares about the LOW ones
        )

    def save_tasks(self) -> None:
        """Persist tasks to storage file, so you can ignore them on disk instead of just in memory"""
        with open(self.storage_file, 'w') as f:
            json.dump({
                "tasks": [task.to_dict() for task in self.tasks.values()]
            }, f, indent=2)  # Pretty print with indent=2 because we're not savages

    def load_tasks(self) -> None:
        """Load tasks from storage file, bringing back all those neglected responsibilities"""
        if not os.path.exists(self.storage_file):
            self.tasks = {}  # No file? No tasks! Freedom!
            return

        try:
            with open(self.storage_file, 'r') as f:
                data = json.load(f)
                self.tasks = {
                    task_data["id"]: Task.from_dict(task_data)
                    for task_data in data.get("tasks", [])
                }
        except (json.JSONDecodeError, KeyError) as e:
            print(f"Error loading tasks: {e}")  # Something went wrong, time to start fresh!
            self.tasks = {}  # Task bankruptcy: the ultimate productivity hack


class TodoApp:
    """Enterprise TODO List Application, for when a sticky note just isn't corporate enough"""

    def __init__(self):
        self.task_manager = TaskManager()  # The keeper of broken promises
        self.parser = self._create_parser()  # CLI parser, because we're too good for a GUI

    def _create_parser(self) -> argparse.ArgumentParser:
        """Create command-line argument parser, with more options than you'll ever use"""
        parser = argparse.ArgumentParser(
            description='Enterprise-grade TODO List Application (because Excel sheets are for amateurs)'
        )
        subparsers = parser.add_subparsers(dest='command', help='Command to execute (or ignore, your choice)')

        # Add task command
        add_parser = subparsers.add_parser('add', help='Add a new task (to ignore later)')
        add_parser.add_argument('title', help='Task title (make it sound important)')
        add_parser.add_argument('-d', '--description', help='Task description (where excuses go to die)')
        add_parser.add_argument(
            '-p', '--priority',
            choices=[p.name for p in Priority],
            default=Priority.MEDIUM.name,
            help='Task priority (how badly you want to avoid it)'
        )
        add_parser.add_argument(
            '--due', help='Due date and time (YYYY-MM-DD HH:MM) (that you\'ll definitely miss)'
        )
        add_parser.add_argument(
            '-t', '--tags', help='Comma-separated list of tags (to create an illusion of organization)'
        )

        # List tasks command
        list_parser = subparsers.add_parser('list', help='List tasks (and feel guilty)')
        list_parser.add_argument(
            '-s', '--status',
            choices=[s.name for s in Status],
            help='Filter by status (protip: NOT_STARTED will show most of them)'
        )
        list_parser.add_argument(
            '-p', '--priority',
            choices=[p.name for p in Priority],
            help='Filter by priority (as if you care about the LOW ones)'
        )
        list_parser.add_argument(
            '-t', '--tag', help='Filter by tag (that complex system you created and immediately abandoned)'
        )

        # View task command
        view_parser = subparsers.add_parser('view', help='View task details (and weep)')
        view_parser.add_argument('id', help='Task ID (that impossible-to-remember UUID)')

        # Update task command
        update_parser = subparsers.add_parser('update', help='Update a task (procrastinate more efficiently)')
        update_parser.add_argument('id', help='Task ID (good luck remembering it)')
        update_parser.add_argument('-T', '--title', help='New task title (because priorities change, am I right?)')
        update_parser.add_argument('-d', '--description', help='New task description (time for a better excuse)')
        update_parser.add_argument(
            '-p', '--priority',
            choices=[p.name for p in Priority],
            help='New task priority (probably increasing to HIGH as the deadline approaches)'
        )
        update_parser.add_argument(
            '-s', '--status',
            choices=[s.name for s in Status],
            help='New task status (optimistically set to IN_PROGRESS)'
        )
        update_parser.add_argument(
            '--due', help='New due date and time (YYYY-MM-DD HH:MM) (pushing it back again, aren\'t you?)'
        )
        update_parser.add_argument(
            '-t', '--tags', help='New comma-separated list of tags (reorganizing your never-used tagging system)'
        )

        # Complete task command (shorthand for update status=COMPLETED)
        complete_parser = subparsers.add_parser('complete', help='Mark a task as completed (sure you did)')
        complete_parser.add_argument('id', help='Task ID (of something you probably delegated)')

        # Delete task command
        delete_parser = subparsers.add_parser('delete', help='Delete a task (the easy way out)')
        delete_parser.add_argument('id', help='Task ID (because deletion is easier than completion)')

        return parser

    def run(self, args: Optional[List[str]] = None) -> None:
        """Run the application with the given arguments, or crash trying"""
        parsed_args = self.parser.parse_args(args)
        
        if not parsed_args.command:
            self.parser.print_help()  # If no command, show help and exit (the equivalent of "I don't know what I'm doing")
            return

        if parsed_args.command == 'add':
            self._handle_add(parsed_args)  # Add another item you'll never do
        elif parsed_args.command == 'list':
            self._handle_list(parsed_args)  # Stare at your failures
        elif parsed_args.command == 'view':
            self._handle_view(parsed_args)  # Look at one particular failure in detail
        elif parsed_args.command == 'update':
            self._handle_update(parsed_args)  # Reschedule, reprioritize, reword, repeat
        elif parsed_args.command == 'complete':
            self._handle_complete(parsed_args)  # Lie to yourself about getting something done
        elif parsed_args.command == 'delete':
            self._handle_delete(parsed_args)  # The ultimate form of task completion

    def _handle_add(self, args: argparse.Namespace) -> None:
        """Handle 'add' command, or as I call it, 'add to my pile of shame'"""
        due_date = None
        if args.due:
            try:
                due_date = datetime.datetime.strptime(args.due, '%Y-%m-%d %H:%M')  # Parse date in a very specific format because flexibility is for the weak
            except ValueError:
                print("Error: Due date must be in the format 'YYYY-MM-DD HH:MM' (computers are so picky)")
                return

        tags = []
        if args.tags:
            tags = [tag.strip() for tag in args.tags.split(',')]  # Split by comma, because we hate our users

        task = Task(
            title=args.title,
            description=args.description or "",
            priority=Priority[args.priority],
            due_date=due_date,
            tags=tags
        )

        task_id = self.task_manager.add_task(task)
        print(f"Task added with ID: {task_id}")  # Print an ID no human will ever memorize

    def _handle_list(self, args: argparse.Namespace) -> None:
        """Handle 'list' command, AKA 'show me my mountain of obligations'"""
        status = Status[args.status] if args.status else None
        priority = Priority[args.priority] if args.priority else None
        
        tasks = self.task_manager.list_tasks(
            status=status,
            priority=priority,
            tag=args.tag
        )

        if not tasks:
            print("No tasks found. Congratulations or you're looking in the wrong place.")
            return

        print(f"Found {len(tasks)} tasks (that's {len(tasks)} too many):")
        for i, task in enumerate(tasks, 1):
            print(f"{i}. {task.id}: {task.title} - {task.status.name}")

    def _handle_view(self, args: argparse.Namespace) -> None:
        """Handle 'view' command, for when you want to see one failure in excruciating detail"""
        task = self.task_manager.get_task(args.id)
        if not task:
            print(f"No task found with ID: {args.id} (lucky you)")
            return

        print(f"ID: {task.id}")
        print(f"Title: {task.title}")
        print(f"Description: {task.description}")
        print(f"Priority: {task.priority}")
        print(f"Status: {task.status}")
        if task.due_date:
            print(f"Due date: {task.due_date.strftime('%Y-%m-%d %H:%M')}")
        if task.tags:
            print(f"Tags: {', '.join(task.tags)}")
        print(f"Created: {task.created_at.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Updated: {task.updated_at.strftime('%Y-%m-%d %H:%M:%S')}")

    def _handle_update(self, args: argparse.Namespace) -> None:
        """Handle 'update' command, for when you want to move the goalposts"""
        update_kwargs = {}
        
        if args.title is not None:
            update_kwargs['title'] = args.title
        if args.description is not None:
            update_kwargs['description'] = args.description
        if args.priority is not None:
            update_kwargs['priority'] = Priority[args.priority]
        if args.status is not None:
            update_kwargs['status'] = Status[args.status]
        
        if args.due is not None:
            if args.due:
                try:
                    update_kwargs['due_date'] = datetime.datetime.strptime(
                        args.due, '%Y-%m-%d %H:%M'  # Again with this format. Sorry, not sorry.
                    )
                except ValueError:
                    print("Error: Due date must be in the format 'YYYY-MM-DD HH:MM' (computers, so literal)")
                    return
            else:
                update_kwargs['due_date'] = None  # No due date = no pressure
                
        if args.tags is not None:
            update_kwargs['tags'] = [tag.strip() for tag in args.tags.split(',')] if args.tags else []

        if not update_kwargs:
            print("No updates specified. Update harder next time.")
            return

        success = self.task_manager.update_task(args.id, **update_kwargs)
        if success:
            print(f"Task {args.id} updated successfully. Your procrastination has been recorded.")
        else:
            print(f"No task found with ID: {args.id} (one less thing to worry about)")

    def _handle_complete(self, args: argparse.Namespace) -> None:
        """Handle 'complete' command, for those rare occasions when you actually finish something"""
        success = self.task_manager.update_task(
            args.id, status=Status.COMPLETED
        )
        if success:
            print(f"Task {args.id} marked as completed. Sure it is.")
        else:
            print(f"No task found with ID: {args.id} (can't complete what doesn't exist)")

    def _handle_delete(self, args: argparse.Namespace) -> None:
        """Handle 'delete' command, the coward's way out"""
        success = self.task_manager.delete_task(args.id)
        if success:
            print(f"Task {args.id} deleted. Out of sight, out of mind!")
        else:
            print(f"No task found with ID: {args.id} (already deleted or never existed, either way it's gone)")


def main():
    """Application entry point, where the magic begins (or more likely crashes)"""
    try:
        TodoApp().run()  # Let's run this baby and see what happens
    except KeyboardInterrupt:
        print("\nApplication terminated by user. Rage quitting is a valid exit strategy.")
        sys.exit(0)  # Clean exit, as if anyone cares
    except Exception as e:
        print(f"An unexpected error occurred: {e}")  # Something broke, shocking
        sys.exit(1)  # Exit with error code, because we're proper software engineers


if __name__ == "__main__":
    main()  # Let the chaos begin
