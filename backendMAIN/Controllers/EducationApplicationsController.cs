// Controllers/ApplicationsController.cs
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.RateLimiting;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")] // Base route: /api/applications
public class EducationApplicationsController : ControllerBase
{
    private readonly EducationApplicationService _educationApplicationService;
    private readonly UserService _userService; // To get user email and phone if available

    public EducationApplicationsController(EducationApplicationService educationApplicationService, UserService userService)
    {
        _educationApplicationService = educationApplicationService;
        _userService = userService;
    }

    [HttpPost] // POST /api/applications
    [AllowAnonymous] // Allow unauthenticated submissions
    [EnableRateLimiting("applications")]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(EducationApplication))] // Explicitly define success response type
    [ProducesResponseType(StatusCodes.Status400BadRequest)] // Explicitly define bad request response type
    public async Task<IActionResult> SubmitEducationApplication([FromBody] CreateEducationApplicationRequest request)
    {
        if (!string.IsNullOrWhiteSpace(request.Website))
        {
            return Accepted(new { message = "Müraciət qəbul edildi." });
        }
        // Model validation is crucial for good API design
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState); // Returns 400 with validation errors
        }
        var educationApplication = await _educationApplicationService.CreateEducationApplicationAsync(request);
        return CreatedAtAction(nameof(GetEducationApplicationById), new { id = educationApplication.Id }, educationApplication);
    }

    [HttpGet] // GET /api/applications // Only Admins can view all applications
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(List<EducationApplication>))] 
    [ProducesResponseType(StatusCodes.Status403Forbidden)] // Explicitly define forbidden response type
    public async Task<ActionResult<List<EducationApplication>>> GetAllEducationApplications()
    {
        var educationApplications = await _educationApplicationService.GetAllEducationApplicationsAsync();
        return Ok(educationApplications); // Returns 200 OK with the list of applications
    }
    [HttpGet("{id:length(24)}")] // Only Admins can view a specific application
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(EducationApplication))]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<EducationApplication>> GetEducationApplicationById(string id)
    {
        var educationApplication = await _educationApplicationService.GetEducationApplicationByIdAsync(id);

        if (educationApplication == null)
        {
            return NotFound(); // Returns 404 Not Found if application with ID is not found
        }
        return Ok(educationApplication); // Returns 200 OK with the application object
    }
    [HttpPut("{id:length(24)}/status")] // Only Admins can update application status
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> UpdateEducationApplicationStatus(string id, [FromBody] UpdateEducationApplicationStatusRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState); // Returns 400 with validation errors
        }

        var success = await _educationApplicationService.UpdateEducationApplicationStatusAsync(id, request.Status);

        if (!success)
        {
            return NotFound(); // Returns 404 Not Found if application with ID is not found
        }
        return NoContent(); // Returns 204 No Content on successful update
    }
    [HttpDelete("{id:length(24)}")] // Only Admins can delete applications
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> DeleteEducationApplication(string id)
    {
        var success = await _educationApplicationService.DeleteEducationApplicationAsync(id);

        if (!success)
        {
            return NotFound(); // Returns 404 Not Found if application with ID is not found
        }
        return NoContent(); // Returns 204 No Content on successful deletion
    }
    public class UpdateEducationApplicationStatusRequest
    {
        [Required]
        public string Status { get; set; } = null!;
    }
}
