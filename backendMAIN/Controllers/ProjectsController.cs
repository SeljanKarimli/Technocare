// Controllers/ProjectsController.cs
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Security.Claims; // For getting user ID from token
using System.Threading.Tasks;
using backend.Models;
using backend.Services;
namespace backend.Controllers;
[ApiController]
[Route("api/internal/legacy/projects")]
[Authorize(Roles = "Admin")]
[ApiExplorerSettings(IgnoreApi = true)]
public class ProjectsController : ControllerBase
{
    private readonly ProjectService _service;

    public ProjectsController(ProjectService projectService)
    {
        _service = projectService;
    }

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<ActionResult<List<Project>>> GetAll()
        => Ok(await _service.GetAllAsync());

    // GET: /api/projects/{id}
    [HttpGet("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<ActionResult<Project>> GetById(string id)
    {
        var project = await _service.GetByIdAsync(id);
        if (project is null) return NotFound(new { message = "Project not found" });
        return Ok(project);
    }

    // POST: /api/projects
    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<ActionResult<Project>> Create([FromBody] ProjectCreateRequest req)
    {
        var created = await _service.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    // PUT: /api/projects/{id}
    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(string id, [FromBody] ProjectUpdateRequest req)
    {
        var ok = await _service.UpdateAsync(id, req);
        if (!ok) return NotFound(new { message = "Project not found" });
        return NoContent();
    }

    // DELETE: /api/projects/{id}
    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(string id)
    {
        var ok = await _service.DeleteAsync(id);
        if (!ok) return NotFound(new { message = "Project not found" });
        return NoContent();
    }
}
