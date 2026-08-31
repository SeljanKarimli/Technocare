// Controllers/ServiceApplicationsController.cs
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Threading.Tasks;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")] // Base route: /api/serviceapplications
public class ServiceApplicationsController : ControllerBase
{
    private readonly ServiceApplicationService _serviceApplicationService;
    private readonly UserService _userService; // To get user email and phone if available

    public ServiceApplicationsController(ServiceApplicationService serviceApplicationService, UserService userService)
    {
        _serviceApplicationService = serviceApplicationService;
        _userService = userService;
    }

    [HttpPost] // POST /api/serviceapplications
    [AllowAnonymous]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(ServiceApplication))] // Explicitly define success response type
    [ProducesResponseType(StatusCodes.Status400BadRequest)] // Explicitly define bad request response type
    public async Task<IActionResult> SubmitApplication([FromBody] CreateServiceApplicationRequest request)
    {
        // Model validation is crucial for good API design
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState); // Returns 400 with validation errors
        }
        var application = await _serviceApplicationService.CreateServiceApplicationAsync(request);
        return CreatedAtAction(nameof(GetApplicationById), new { id = application.Id }, application);
    }

    [HttpGet] // GET /api/serviceapplications // Only Admins can view all applications
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(List<ServiceApplication>))]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<List<ServiceApplication>> GetAllApplications() =>
        await _serviceApplicationService.GetAllServiceApplicationsAsync();

    [HttpGet("{id:length(24)}", Name = "GetApplicationById")] // Only Admins can get a single application
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ServiceApplication))]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetApplicationById(string id)
    {
        var application = await _serviceApplicationService.GetServiceApplicationByIdAsync(id);
        if (application == null)
        {
            return NotFound();
        }
        return Ok(application);
    }
    public class UpdateApplicationStatusRequest
    {
        [Required]
        public string Status { get; set; } = null!;
    }

    [HttpPut("{id:length(24)}/status")] // Only Admins can update application status
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> UpdateApplicationStatus(string id, [FromBody] UpdateApplicationStatusRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState); // Returns 400 with validation errors
        }

        var success = await _serviceApplicationService.UpdateServiceApplicationStatusAsync(id, request.Status);

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
    public async Task<IActionResult> DeleteApplication(string id)
    {
        var success = await _serviceApplicationService.DeleteServiceApplicationAsync(id);

        if (!success)
        {
            return NotFound(); // Returns 404 Not Found if application with ID is not found
        }
        return NoContent(); // Returns 204 No Content on successful deletion
    }
}
