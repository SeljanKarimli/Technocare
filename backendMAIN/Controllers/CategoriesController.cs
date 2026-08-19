using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly CategoryService _categoryService;

    public CategoriesController(CategoryService categoryService)
    {
        _categoryService = categoryService;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Category>>> Get()
    {
        var list = await _categoryService.GetAsync();
        return Ok(list);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Category>> GetById(string id)
    {
        var item = await _categoryService.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }

    [HttpPost]
    public async Task<ActionResult<Category>> Create(Category category)
    {
        await _categoryService.CreateAsync(category);
        return CreatedAtAction(nameof(GetById), new { id = category.Id }, category);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, Category updated)
    {
        var existing = await _categoryService.GetByIdAsync(id);
        if (existing == null) return NotFound();

        updated.Id = existing.Id;
        var success = await _categoryService.UpdateAsync(id, updated);
        if (!success) return StatusCode(500, "Failed to update category.");

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var existing = await _categoryService.GetByIdAsync(id);
        if (existing == null) return NotFound();

        var success = await _categoryService.DeleteAsync(id);
        if (!success) return StatusCode(500, "Failed to delete category.");

        return NoContent();
    }
}
